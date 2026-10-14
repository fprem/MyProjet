from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from jira_kpi.app.data import PRESETS, load_dataset, period_for_preset
from jira_kpi.demo import demo_settings, generate_raw_issues
from jira_kpi.storage.repository import IssueRepository
from tests.builders import dt

ROME = ZoneInfo("Europe/Rome")


class TestPeriodForPreset:
    def test_last_14_days_ends_at_end_of_today_local(self) -> None:
        now = datetime(2026, 1, 20, 15, tzinfo=ROME)
        period = period_for_preset("Ultime 2 settimane", now, ROME)
        assert period.end == datetime(2026, 1, 21, tzinfo=ROME)
        assert period.start == datetime(2026, 1, 7, tzinfo=ROME)

    @pytest.mark.parametrize("preset", list(PRESETS))
    def test_all_presets_produce_valid_periods(self, preset: str) -> None:
        period = period_for_preset(preset, dt(20), ROME)
        assert period.length.days == PRESETS[preset]

    def test_unknown_preset(self) -> None:
        with pytest.raises(KeyError):
            period_for_preset("boh", dt(20), ROME)


def test_load_dataset_maps_raw_issues(tmp_path: Path) -> None:
    settings = demo_settings(str(tmp_path / "demo.sqlite"))
    now = dt(14, month=10)
    with IssueRepository(settings.db_path) as repo:
        repo.upsert(generate_raw_issues(now))
        repo.set_last_sync(now)
    dataset = load_dataset(settings)
    assert len(dataset.issues) > 50
    assert dataset.sprints
    assert dataset.last_sync == now


def test_load_dataset_empty_db(tmp_path: Path) -> None:
    dataset = load_dataset(demo_settings(str(tmp_path / "empty.sqlite")))
    assert dataset.issues == []
    assert dataset.last_sync is None
