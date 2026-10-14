"""Figure Plotly per la dashboard (palette di riferimento, una sola scala y per grafico)."""

from __future__ import annotations

import plotly.graph_objects as go

from jira_kpi.app.viewmodel import DashboardData
from jira_kpi.domain.models import StatusCategory

# Palette categoriale di riferimento, ordine fisso (slot 1-4 validati sulle coppie adiacenti).
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
NEUTRAL = "#52514e"
GRID = "rgba(128,128,128,0.18)"

CATEGORY_LABELS = {
    StatusCategory.DONE: "Done",
    StatusCategory.WAITING: "In attesa",
    StatusCategory.IN_PROGRESS: "In corso",
    StatusCategory.TODO: "Da fare",
}
# Il colore segue l'entità: ogni categoria ha sempre lo stesso slot.
CATEGORY_COLORS = dict(zip(CATEGORY_LABELS, SERIES, strict=True))


def _layout(fig: go.Figure, *, y_title: str, legend: bool = False) -> go.Figure:
    fig.update_layout(
        margin={"l": 8, "r": 8, "t": 8, "b": 8},
        height=320,
        showlegend=legend,
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "x": 0},
        hovermode="x unified",
        bargap=0.35,
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
    )
    fig.update_xaxes(showgrid=False, linecolor=GRID)
    fig.update_yaxes(title_text=y_title, gridcolor=GRID, zeroline=False, rangemode="tozero")
    return fig


def throughput_chart(data: DashboardData) -> go.Figure:
    fig = go.Figure(
        go.Bar(
            x=[week for week, _ in data.throughput],
            y=[count for _, count in data.throughput],
            marker={"color": SERIES[0], "cornerradius": 4},
            name="Completate",
            hovertemplate="Settimana del %{x|%d %b}<br>%{y} issue completate<extra></extra>",
        )
    )
    return _layout(fig, y_title="issue / settimana")


def cfd_chart(data: DashboardData) -> go.Figure:
    days = [day for day, _ in data.cfd]
    fig = go.Figure()
    for category, label in CATEGORY_LABELS.items():
        fig.add_trace(
            go.Scatter(
                x=days,
                y=[counts.get(category, 0) for _, counts in data.cfd],
                name=label,
                mode="lines",
                stackgroup="cfd",
                line={"width": 2, "color": CATEGORY_COLORS[category]},
                hovertemplate=f"{label}: %{{y}}<extra></extra>",
            )
        )
    return _layout(fig, y_title="issue", legend=True)


def cycle_time_chart(data: DashboardData) -> go.Figure:
    points = data.cycle_time_points
    fig = go.Figure(
        go.Scatter(
            x=[p.completed_at for p in points],
            y=[p.days for p in points],
            text=[p.key for p in points],
            mode="markers",
            marker={"size": 9, "color": SERIES[0], "line": {"width": 2, "color": "white"}},
            name="Cycle time",
            hovertemplate="%{text}<br>%{y:.1f} giorni<br>chiusa il %{x|%d %b}<extra></extra>",
        )
    )
    stats = data.cycle_time_stats
    if stats:
        for label, value in (("p50", stats.p50), ("p85", stats.p85)):
            fig.add_hline(
                y=value,
                line={"color": NEUTRAL, "width": 1, "dash": "dash" if label == "p85" else "dot"},
                annotation_text=f"{label}: {value:.1f} gg",
                annotation_position="top left",
                annotation_font_color=NEUTRAL,
            )
    _layout(fig, y_title="giorni")
    fig.update_layout(hovermode="closest")
    return fig


def velocity_chart(data: DashboardData) -> go.Figure:
    names = [r.sprint.name for r in data.sprints]
    fig = go.Figure()
    fig.add_trace(
        go.Bar(
            x=names,
            y=[r.committed_points for r in data.sprints],
            name="Committati",
            marker={"color": SERIES[0], "cornerradius": 4},
            hovertemplate="%{y:g} SP committati<extra></extra>",
        )
    )
    fig.add_trace(
        go.Bar(
            x=names,
            y=[r.completed_points for r in data.sprints],
            name="Completati",
            marker={"color": SERIES[1], "cornerradius": 4},
            hovertemplate="%{y:g} SP completati<extra></extra>",
        )
    )
    fig.add_trace(
        go.Scatter(
            x=names,
            y=data.velocity_trend,
            name="Media mobile (3)",
            mode="lines",
            line={"color": NEUTRAL, "width": 2, "dash": "dash"},
            hovertemplate="media %{y:.1f} SP<extra></extra>",
        )
    )
    _layout(fig, y_title="story points", legend=True)
    fig.update_layout(barmode="group", bargroupgap=0.08)
    return fig


def say_do_chart(data: DashboardData) -> go.Figure:
    names = [r.sprint.name for r in data.sprints]
    values = [
        None if r.say_do_ratio is None else round(r.say_do_ratio * 100, 1) for r in data.sprints
    ]
    fig = go.Figure(
        go.Scatter(
            x=names,
            y=values,
            mode="lines+markers",
            line={"color": SERIES[0], "width": 2},
            marker={"size": 8},
            name="Say/Do",
            hovertemplate="%{y:.0f}% del commitment completato<extra></extra>",
        )
    )
    _layout(fig, y_title="% commitment completato")
    fig.update_yaxes(range=[0, 105])
    return fig
