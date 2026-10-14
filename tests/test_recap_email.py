from datetime import date

from recap.notes_parser import Commitment, Meeting
from recap.recap_email import draft_recap


def make_meeting():
    return Meeting(
        title="Website redesign",
        agreements=["Homepage goes live in two phases"],
        decisions=["We drop the blog section for now"],
        commitments=[
            Commitment(owner="Maria", task="send brand feedback", due=date(2026, 10, 20)),
            Commitment(owner=None, task="book the venue", due=None),
        ],
    )


def test_subject_names_client_and_meeting():
    email = draft_recap(make_meeting(), client="Acme", pm_name="Fabrizio", call_date=date(2026, 10, 14))
    assert email.subject == "Recap: Website redesign (Acme, 14 Oct 2026)"


def test_body_lists_agreements_decisions_and_who_does_what_by_when():
    body = draft_recap(make_meeting(), client="Acme", pm_name="Fabrizio", call_date=date(2026, 10, 14)).body
    assert "What we agreed" in body
    assert "- Homepage goes live in two phases" in body
    assert "Decisions" in body
    assert "- We drop the blog section for now" in body
    assert "Next steps" in body
    assert "- Maria: send brand feedback (by Tue 20 Oct)" in body
    assert "- To be assigned: book the venue" in body


def test_body_is_signed_by_the_pm_never_by_the_tool():
    body = draft_recap(make_meeting(), client="Acme", pm_name="Fabrizio", call_date=date(2026, 10, 14)).body
    assert body.rstrip().endswith("Fabrizio")
    assert "recap tool" not in body.lower()


def test_empty_sections_are_omitted():
    meeting = Meeting(title=None, commitments=[Commitment(owner="Ana", task="share the plan", due=None)])
    email = draft_recap(meeting, client="Acme", pm_name="Fabrizio", call_date=date(2026, 10, 14))
    assert "What we agreed" not in email.body
    assert "Decisions" not in email.body
    assert email.subject == "Recap: our call (Acme, 14 Oct 2026)"


def test_as_text_combines_subject_and_body():
    email = draft_recap(make_meeting(), client="Acme", pm_name="Fabrizio", call_date=date(2026, 10, 14))
    assert email.as_text().startswith("Subject: Recap: Website redesign")
    assert email.body in email.as_text()
