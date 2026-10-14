from datetime import date

from recap.notes_parser import Commitment, parse_notes

NOTES = """\
Call with Acme about the website redesign
Agreed: homepage goes live in two phases
Decision: we drop the blog section for now
Action: Maria (Acme) to send brand feedback by 2026-10-20
Action: Paolo will confirm the print supplier date by 2026-10-17
TODO: Fabrizio to deliver the first draft
some unrelated chatter
"""


def test_parses_agreements_and_decisions():
    meeting = parse_notes(NOTES)
    assert meeting.agreements == ["Homepage goes live in two phases"]
    assert meeting.decisions == ["We drop the blog section for now"]


def test_parses_commitments_with_owner_task_and_due_date():
    meeting = parse_notes(NOTES)
    assert meeting.commitments[0] == Commitment(
        owner="Maria (Acme)", task="send brand feedback", due=date(2026, 10, 20)
    )
    assert meeting.commitments[1] == Commitment(
        owner="Paolo", task="confirm the print supplier date", due=date(2026, 10, 17)
    )


def test_commitment_without_due_date():
    meeting = parse_notes(NOTES)
    assert meeting.commitments[2] == Commitment(
        owner="Fabrizio", task="deliver the first draft", due=None
    )


def test_first_unprefixed_line_is_the_title_and_chatter_is_ignored():
    meeting = parse_notes(NOTES)
    assert meeting.title == "Call with Acme about the website redesign"
    assert len(meeting.commitments) == 3


def test_prefixes_are_case_insensitive_and_bullets_are_stripped():
    meeting = parse_notes("- agreed: weekly sync on Mondays\n* ACTION: Ana to share the plan")
    assert meeting.agreements == ["Weekly sync on Mondays"]
    assert meeting.commitments == [Commitment(owner="Ana", task="share the plan", due=None)]


def test_action_without_owner_keeps_text_as_task():
    meeting = parse_notes("Action: book the venue")
    assert meeting.commitments == [Commitment(owner=None, task="book the venue", due=None)]


def test_empty_notes():
    meeting = parse_notes("")
    assert meeting.title is None
    assert meeting.is_empty()
