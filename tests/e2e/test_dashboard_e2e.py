import pytest

pytest.importorskip("playwright")

from playwright.sync_api import Page, expect

pytestmark = pytest.mark.e2e


def test_user_explores_kpis(page: Page, dashboard_url: str) -> None:
    page.goto(dashboard_url)
    expect(page.get_by_role("heading", name="KPI di team")).to_be_visible(timeout=30_000)
    expect(page.get_by_text("dati demo")).to_be_visible()
    expect(page.get_by_test_id("stMetric")).to_have_count(9)

    page.get_by_role("tab", name="Sprint").click()
    expect(page.get_by_role("heading", name="Velocity")).to_be_visible()

    page.get_by_role("tab", name="Qualità").click()
    expect(
        page.get_by_role("heading", name="Tempo di risoluzione dei bug per priorità")
    ).to_be_visible()
