from recap.cli import main

NOTES = """Website redesign
Agreed: homepage goes live in two phases
Action: Maria to send brand feedback by 2026-10-20
"""


def run(args, capsys):
    code = main(args)
    return code, capsys.readouterr().out


def test_draft_prints_recap_email(tmp_path, capsys):
    notes = tmp_path / "notes.txt"
    notes.write_text(NOTES)
    code, out = run(["draft", str(notes), "--client", "Acme", "--pm", "Fabrizio", "--date", "2026-10-14"], capsys)
    assert code == 0
    assert "Subject: Recap: Website redesign (Acme, 14 Oct 2026)" in out
    assert "- Maria: send brand feedback (by Tue 20 Oct)" in out


def test_draft_with_save_records_commitments_and_open_lists_them(tmp_path, capsys):
    notes = tmp_path / "notes.txt"
    notes.write_text(NOTES)
    db = tmp_path / "db.json"
    run(["--db", str(db), "draft", str(notes), "--client", "Acme", "--pm", "F", "--date", "2026-10-14", "--save"], capsys)
    code, out = run(["--db", str(db), "open", "--client", "Acme"], capsys)
    assert code == 0
    assert "Maria" in out and "send brand feedback" in out and "2026-10-20" in out


def test_done_closes_commitment(tmp_path, capsys):
    notes = tmp_path / "notes.txt"
    notes.write_text(NOTES)
    db = tmp_path / "db.json"
    run(["--db", str(db), "draft", str(notes), "--client", "Acme", "--pm", "F", "--save"], capsys)
    code, _ = run(["--db", str(db), "done", "1"], capsys)
    assert code == 0
    _, out = run(["--db", str(db), "open"], capsys)
    assert "No open commitments" in out


def test_done_unknown_id_returns_error(tmp_path, capsys):
    code, _ = run(["--db", str(tmp_path / "db.json"), "done", "42"], capsys)
    assert code == 1


def test_draft_reads_stdin_when_path_is_dash(monkeypatch, capsys):
    import io
    monkeypatch.setattr("sys.stdin", io.StringIO(NOTES))
    code, out = run(["draft", "-", "--client", "Acme", "--pm", "F", "--date", "2026-10-14"], capsys)
    assert code == 0
    assert "Website redesign" in out


def test_draft_with_ai_flag_falls_back_with_notice_when_ai_fails(tmp_path, capsys, monkeypatch):
    from recap import ai_extractor

    def boom(text, call_date, client=None):
        raise ai_extractor.AIDraftingError("AI drafting failed: no key.")

    monkeypatch.setattr("recap.drafting.extract_with_ai", boom)
    notes = tmp_path / "notes.txt"
    notes.write_text(NOTES)
    code = main(["draft", str(notes), "--client", "Acme", "--pm", "F", "--date", "2026-10-14", "--ai"])
    captured = capsys.readouterr()
    assert code == 0
    assert "no key" in captured.err
    assert "- Maria: send brand feedback" in captured.out
