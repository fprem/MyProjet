from datetime import date, datetime

import pytest

from recap.metrics import CallRecord, edit_share, summarize


def test_edit_share_is_zero_for_identical_text():
    assert edit_share("Hello Maria, thanks for the call.", "Hello Maria, thanks for the call.") == 0.0


def test_edit_share_is_one_for_completely_rewritten_text():
    assert edit_share("aaaa", "zzzz") == 1.0


def test_edit_share_partial_edit():
    share = edit_share("one two three four five", "one two three four six")
    assert 0 < share < 0.3


def make_records():
    return [
        CallRecord(
            call_date=date(2026, 10, 1), pm="Ana", sent=True,
            draft="Hi all, recap below.", final="Hi all, recap below.",
            call_end=datetime(2026, 10, 1, 10, 0), sent_at=datetime(2026, 10, 1, 10, 3),
            missed_commitments=0,
        ),
        CallRecord(
            call_date=date(2026, 10, 2), pm="Ana", sent=True,
            draft="Hi all, recap below.", final="Hello team, here is the recap.",
            call_end=datetime(2026, 10, 2, 10, 0), sent_at=datetime(2026, 10, 2, 10, 9),
            missed_commitments=2,
        ),
        CallRecord(call_date=date(2026, 10, 3), pm="Ben", sent=False, draft="Draft", missed_commitments=1),
    ]


def test_summary_send_rate():
    assert summarize(make_records()).send_rate == pytest.approx(2 / 3)


def test_summary_median_minutes_to_send_uses_sent_calls_only():
    assert summarize(make_records()).median_minutes_to_send == 6.0


def test_summary_missed_commitments_per_call():
    assert summarize(make_records()).missed_per_call == 1.0


def test_summary_average_edit_share_uses_sent_calls_only():
    s = summarize(make_records())
    assert 0 < s.avg_edit_share < 1


def test_summary_checks_targets_from_the_one_pager():
    s = summarize(make_records())
    assert s.targets == {
        "send_rate>=70%": False,
        "edit_share<20%": s.avg_edit_share < 0.20,
        "minutes_to_send<5": False,
        "missed_per_call<1": False,
    }


def test_summary_of_no_records():
    s = summarize([])
    assert s.calls == 0
    assert s.send_rate == 0.0
    assert s.median_minutes_to_send is None
