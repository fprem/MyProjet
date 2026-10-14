from zoneinfo import ZoneInfo

from jira_kpi.app import charts
from jira_kpi.app.viewmodel import build_dashboard
from jira_kpi.demo import DEMO_MAPPING, generate_raw_issues
from jira_kpi.domain.models import Period
from jira_kpi.jira.mapper import IssueMapper
from tests.builders import dt

NOW = dt(14, 12, month=10)
MAPPER = IssueMapper("customfield_10016", "customfield_10020")
RAWS = generate_raw_issues(NOW)
DATA = build_dashboard(
    [MAPPER.to_issue(r) for r in RAWS],
    MAPPER.extract_sprints(RAWS),
    DEMO_MAPPING,
    Period(dt(1, month=8), dt(15, month=10)),
    now=NOW,
    tz=ZoneInfo("UTC"),
    bug_types=["Bug"],
)


def test_throughput_single_bar_series() -> None:
    fig = charts.throughput_chart(DATA)
    assert [t.type for t in fig.data] == ["bar"]
    assert fig.layout.showlegend is False


def test_cfd_has_one_trace_per_category_done_first() -> None:
    fig = charts.cfd_chart(DATA)
    assert [t.name for t in fig.data] == ["Done", "In attesa", "In corso", "Da fare"]
    assert len({t.line.color for t in fig.data}) == 4


def test_cycle_time_scatter_has_percentile_lines() -> None:
    fig = charts.cycle_time_chart(DATA)
    assert fig.data[0].mode == "markers"
    labels = {a.text for a in fig.layout.annotations}
    assert any(label.startswith("p85") for label in labels)
    assert any(label.startswith("p50") for label in labels)


def test_velocity_chart_committed_vs_completed() -> None:
    fig = charts.velocity_chart(DATA)
    assert [t.name for t in fig.data] == ["Committati", "Completati", "Media mobile (3)"]


def test_say_do_chart_in_percent() -> None:
    fig = charts.say_do_chart(DATA)
    assert all(0 <= y <= 100 for y in fig.data[0].y if y is not None)


def test_charts_handle_empty_data() -> None:
    empty = build_dashboard(
        [],
        [],
        DEMO_MAPPING,
        Period(dt(1), dt(15)),
        now=dt(14),
        tz=ZoneInfo("UTC"),
        bug_types=["Bug"],
    )
    for build in (
        charts.throughput_chart,
        charts.cfd_chart,
        charts.cycle_time_chart,
        charts.velocity_chart,
        charts.say_do_chart,
    ):
        build(empty)
