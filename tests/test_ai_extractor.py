from datetime import date
from types import SimpleNamespace

import pytest

from recap.ai_extractor import (
    MODEL,
    AIDraftingError,
    ExtractedCommitment,
    ExtractedMeeting,
    extract_with_ai,
)
from recap.notes_parser import Commitment


class FakeMessages:
    def __init__(self, parsed=None, stop_reason="end_turn"):
        self.parsed = parsed
        self.stop_reason = stop_reason
        self.calls = []

    def parse(self, **kwargs):
        self.calls.append(kwargs)
        return SimpleNamespace(parsed_output=self.parsed, stop_reason=self.stop_reason)


def fake_client(parsed=None, stop_reason="end_turn"):
    messages = FakeMessages(parsed, stop_reason)
    return SimpleNamespace(beta=SimpleNamespace(messages=messages)), messages


EXTRACTED = ExtractedMeeting(
    title="Website redesign",
    agreements=["Homepage goes live in two phases"],
    decisions=["We drop the blog section for now"],
    commitments=[
        ExtractedCommitment(owner="Maria", task="send brand feedback", due="2026-10-16"),
        ExtractedCommitment(owner=None, task="book the venue", due=None),
    ],
)


def test_converts_extracted_output_to_meeting():
    client, _ = fake_client(EXTRACTED)
    meeting = extract_with_ai("free-form notes", call_date=date(2026, 10, 14), client=client)
    assert meeting.title == "Website redesign"
    assert meeting.agreements == ["Homepage goes live in two phases"]
    assert meeting.decisions == ["We drop the blog section for now"]
    assert meeting.commitments == [
        Commitment(owner="Maria", task="send brand feedback", due=date(2026, 10, 16)),
        Commitment(owner=None, task="book the venue", due=None),
    ]


def test_request_sends_notes_and_call_date_with_structured_output():
    client, messages = fake_client(EXTRACTED)
    extract_with_ai("Maria sends feedback Friday", call_date=date(2026, 10, 14), client=client)
    call = messages.calls[0]
    assert call["model"] == MODEL == "claude-opus-5-5"
    assert call["output_format"] is ExtractedMeeting
    user_text = call["messages"][0]["content"]
    assert "Maria sends feedback Friday" in user_text
    assert "2026-10-14" in user_text


def test_bad_due_date_from_model_becomes_none():
    bad = ExtractedMeeting(commitments=[ExtractedCommitment(owner="A", task="t", due="next Friday")])
    client, _ = fake_client(bad)
    meeting = extract_with_ai("notes", call_date=date(2026, 10, 14), client=client)
    assert meeting.commitments[0].due is None


def test_refusal_raises():
    client, _ = fake_client(None, stop_reason="refusal")
    with pytest.raises(AIDraftingError):
        extract_with_ai("notes", call_date=date(2026, 10, 14), client=client)


def test_missing_parsed_output_raises():
    client, _ = fake_client(None, stop_reason="max_tokens")
    with pytest.raises(AIDraftingError):
        extract_with_ai("notes", call_date=date(2026, 10, 14), client=client)


def test_client_errors_are_wrapped():
    class Boom:
        def parse(self, **kwargs):
            raise RuntimeError("no network")

    client = SimpleNamespace(beta=SimpleNamespace(messages=Boom()))
    with pytest.raises(AIDraftingError):
        extract_with_ai("notes", call_date=date(2026, 10, 14), client=client)
