"""Smoke test della pagina Streamlit con dati demo (senza browser)."""

from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

DASHBOARD = Path(__file__).parents[2] / "src" / "jira_kpi" / "app" / "dashboard.py"


@pytest.fixture
def demo_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JIRA_KPI_DEMO", "1")
    monkeypatch.setenv("JIRA_KPI_DEMO_DB", str(tmp_path / "demo.sqlite"))


@pytest.mark.usefixtures("demo_env")
def test_renders_tiles_and_tabs_without_errors() -> None:
    app = AppTest.from_file(str(DASHBOARD), default_timeout=30).run()
    assert not app.exception
    assert app.title[0].value == "KPI di team"
    labels = [m.label for m in app.metric]
    assert labels[:3] == ["Throughput", "Cycle time p85", "Lead time p50"]
    assert [t.label for t in app.tabs] == ["Flusso", "Sprint", "Qualità"]


@pytest.mark.usefixtures("demo_env")
def test_changing_period_rerenders() -> None:
    app = AppTest.from_file(str(DASHBOARD), default_timeout=30).run()
    app.selectbox[0].select("Ultime 2 settimane").run()
    assert not app.exception


def test_invalid_config_shows_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("JIRA_KPI_DEMO", raising=False)
    monkeypatch.setenv("JIRA_KPI_CONFIG", "/non/esiste.yaml")
    app = AppTest.from_file(str(DASHBOARD), default_timeout=30).run()
    assert "Configurazione non valida" in app.error[0].value
