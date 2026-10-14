import pytest

from recap.notes_parser import Commitment, Meeting
from recap.web import create_app

NOTES = "Website redesign\nAgreed: homepage goes live in two phases\nAction: Maria to send brand feedback by 2026-10-20\n"


@pytest.fixture
def make_client(tmp_path):
    def _make(extractor=None):
        app = create_app(db_path=tmp_path / "db.json", extractor=extractor)
        app.config["TESTING"] = True
        return app.test_client()
    return _make


def draft(http, **overrides):
    form = {"notes": NOTES, "client": "Acme", "pm": "Fabrizio", "date": "2026-10-14"}
    form.update(overrides)
    return http.post("/draft", data=form)


def test_home_page_shows_the_notes_form(make_client):
    page = make_client().get("/").get_data(as_text=True)
    assert "<form" in page
    for field in ('name="notes"', 'name="client"', 'name="pm"', 'name="use_ai"'):
        assert field in page


def test_draft_shows_the_recap_email(make_client):
    resp = draft(make_client())
    page = resp.get_data(as_text=True)
    assert resp.status_code == 200
    assert "Recap: Website redesign (Acme, 14 Oct 2026)" in page
    assert "- Maria: send brand feedback (by Tue 20 Oct)" in page


def test_draft_saves_commitments_and_open_page_lists_them(make_client):
    client = make_client()
    draft(client)
    page = client.get("/open").get_data(as_text=True)
    assert "Maria" in page and "send brand feedback" in page and "2026-10-20" in page


def test_open_page_filters_by_client(make_client):
    client = make_client()
    draft(client)
    draft(client, client="Globex", notes="Action: Ana to share the plan")
    page = client.get("/open?client=Globex").get_data(as_text=True)
    assert "share the plan" in page
    assert "send brand feedback" not in page


def test_mark_done_removes_commitment(make_client):
    client = make_client()
    draft(client)
    resp = client.post("/done/1")
    assert resp.status_code == 302
    assert "send brand feedback" not in client.get("/open").get_data(as_text=True)


def test_missing_fields_return_400(make_client):
    resp = draft(make_client(), notes="  ")
    assert resp.status_code == 400


def test_ai_checkbox_uses_the_ai_extractor(make_client):
    calls = []

    def extractor(text, call_date):
        calls.append(text)
        return Meeting(title="AI title", commitments=[Commitment("Paolo", "confirm the date", None)])

    page = draft(make_client(extractor), use_ai="on").get_data(as_text=True)
    assert calls == [NOTES]
    assert "Recap: AI title" in page
    assert "- Paolo: confirm the date" in page


def test_ai_failure_shows_notice_and_uses_rules(make_client):
    from recap.ai_extractor import AIDraftingError

    def extractor(text, call_date):
        raise AIDraftingError("ANTHROPIC_API_KEY is not set")

    page = draft(make_client(extractor), use_ai="on").get_data(as_text=True)
    assert "ANTHROPIC_API_KEY is not set" in page
    assert "- Maria: send brand feedback" in page


def test_user_input_is_escaped(make_client):
    page = draft(make_client(), client="<script>x</script>").get_data(as_text=True)
    assert "<script>x</script>" not in page
