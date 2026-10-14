from datetime import date

from recap.ai_extractor import AIDraftingError
from recap.drafting import build_meeting
from recap.notes_parser import Commitment, Meeting

RULE_NOTES = "Kickoff\nAction: Ana to share the plan"


def test_rules_mode_uses_the_prefix_parser():
    meeting, notice = build_meeting(RULE_NOTES, call_date=date(2026, 10, 14), use_ai=False)
    assert meeting.commitments == [Commitment("Ana", "share the plan", None)]
    assert notice is None


def test_ai_mode_uses_the_extractor():
    ai_meeting = Meeting(title="From AI")
    meeting, notice = build_meeting(
        "anything", call_date=date(2026, 10, 14), use_ai=True, extractor=lambda text, call_date: ai_meeting
    )
    assert meeting is ai_meeting
    assert notice is None


def test_ai_failure_falls_back_to_rules_with_a_notice():
    def failing(text, call_date):
        raise AIDraftingError("no API key")

    meeting, notice = build_meeting(RULE_NOTES, call_date=date(2026, 10, 14), use_ai=True, extractor=failing)
    assert meeting.commitments == [Commitment("Ana", "share the plan", None)]
    assert "no API key" in notice
