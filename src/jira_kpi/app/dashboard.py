"""Dashboard Streamlit. Avvio: `jira-kpi dashboard [--demo | --config config.yaml]`."""

from __future__ import annotations

import os
from datetime import UTC, datetime

import streamlit as st

from jira_kpi.app import charts
from jira_kpi.app.data import PRESETS, Dataset, load_dataset, period_for_preset
from jira_kpi.app.viewmodel import DashboardData, KpiTile, build_dashboard
from jira_kpi.config import Settings, load_settings
from jira_kpi.demo import demo_settings, ensure_demo_db


def _settings() -> tuple[Settings, bool]:
    if os.environ.get("JIRA_KPI_DEMO") == "1":
        settings = demo_settings(os.environ.get("JIRA_KPI_DEMO_DB", "data/demo.sqlite"))
        ensure_demo_db(settings.db_path, datetime.now(UTC))
        return settings, True
    return load_settings(os.environ.get("JIRA_KPI_CONFIG", "config.yaml")), False


@st.cache_data(ttl=300, show_spinner="Caricamento snapshot…")
def _dataset(settings_json: str) -> Dataset:
    return load_dataset(Settings.model_validate_json(settings_json))


def _fmt(tile: KpiTile, value: float | None) -> str:
    if value is None:
        return "—"
    if tile.unit == "%":
        return f"{value * 100:.0f}%"
    if tile.unit == "giorni":
        return f"{value:.1f} gg"
    return f"{value:g} {tile.unit}" if tile.unit == "SP" else f"{value:g}"


def _delta(tile: KpiTile) -> str | None:
    if tile.delta is None:
        return None
    if tile.unit == "%":
        return f"{tile.delta * 100:+.0f} pp"
    return f"{tile.delta:+.1f}" if tile.unit == "giorni" else f"{tile.delta:+g}"


def _tiles(data: DashboardData) -> None:
    for row in (data.tiles[:5], data.tiles[5:]):
        for column, tile in zip(st.columns(5), row, strict=False):
            column.metric(
                tile.label,
                _fmt(tile, tile.value),
                _delta(tile),
                delta_color="off"
                if tile.trend == "flat"
                else ("normal" if tile.higher_is_better else "inverse"),
                help=f"{tile.help}. Delta vs periodo precedente: {_fmt(tile, tile.previous)}.",
            )


def _flow_tab(data: DashboardData) -> None:
    left, right = st.columns(2)
    with left:
        st.subheader("Throughput settimanale")
        st.plotly_chart(charts.throughput_chart(data))
    with right:
        st.subheader("Cycle time per issue")
        st.plotly_chart(charts.cycle_time_chart(data))
    st.subheader("Cumulative flow")
    st.plotly_chart(charts.cfd_chart(data))
    st.subheader("Aging WIP")
    p85 = data.cycle_time_stats.p85 if data.cycle_time_stats else None
    if not data.aging:
        st.info("Nessuna issue in lavorazione.")
    else:
        st.dataframe(
            [
                {
                    "Issue": a.key,
                    "Stato": a.status,
                    "Età (gg)": round(a.age_days, 1),
                    "Oltre p85": "⚠️ sì" if p85 is not None and a.age_days > p85 else "no",
                }
                for a in data.aging
            ],
            hide_index=True,
        )


def _sprint_tab(data: DashboardData) -> None:
    if data.active_sprint:
        r = data.active_sprint
        st.info(
            f"Sprint in corso **{r.sprint.name}**: {r.completed_points:g} di "
            f"{r.scope_points:g} SP completati, "
            f"{r.added_points:g} SP aggiunti dopo l'avvio. "
            "Escluso dai grafici di trend finché non viene chiuso."
        )
    if not data.sprints:
        st.info("Nessuno sprint chiuso nei dati: le metriche Scrum non sono ancora disponibili.")
        return
    left, right = st.columns(2)
    with left:
        st.subheader("Velocity")
        st.plotly_chart(charts.velocity_chart(data))
    with right:
        st.subheader("Say/Do (commitment reliability)")
        st.plotly_chart(charts.say_do_chart(data))
    st.subheader("Dettaglio sprint")
    st.dataframe(
        [
            {
                "Sprint": r.sprint.name,
                "SP committati": r.committed_points,
                "SP aggiunti": r.added_points,
                "SP rimossi": r.removed_points,
                "SP completati": r.completed_points,
                "Carry-over (issue)": r.carried_over_count,
                "Say/Do": None if r.say_do_ratio is None else f"{r.say_do_ratio:.0%}",
            }
            for r in data.sprints
        ],
        hide_index=True,
    )


def _quality_tab(data: DashboardData) -> None:
    st.subheader("Tempo di risoluzione dei bug per priorità")
    if not data.bug_resolution:
        st.info("Nessun bug risolto nel periodo.")
        return
    st.dataframe(
        [
            {
                "Priorità": priority,
                "Bug risolti": s.count,
                "p50 (gg)": round(s.p50, 1),
                "p85 (gg)": round(s.p85, 1),
                "Media (gg)": round(s.mean, 1),
            }
            for priority, s in sorted(data.bug_resolution.items())
        ],
        hide_index=True,
    )


def main() -> None:
    st.set_page_config(page_title="KPI di team da Jira", page_icon="📊", layout="wide")
    try:
        settings, is_demo = _settings()
    except Exception as exc:  # configurazione mancante/non valida: messaggio chiaro in UI
        st.error(f"Configurazione non valida: {exc}")
        st.stop()
        return
    dataset = _dataset(settings.model_dump_json())

    st.title("KPI di team")
    sync_info = (
        dataset.last_sync.astimezone(settings.tz).strftime("%d/%m/%Y %H:%M")
        if dataset.last_sync
        else "mai"
    )
    st.caption(
        f"Progetto **{settings.project}** · Team **{settings.team}** · "
        f"ultima sync: {sync_info}" + (" · 🧪 dati demo" if is_demo else "")
    )
    if not dataset.issues:
        st.warning("Lo snapshot è vuoto: eseguire `jira-kpi sync --config config.yaml`.")
        st.stop()

    with st.sidebar:
        st.header("Filtri")
        preset = st.selectbox("Periodo", list(PRESETS), index=2)
        types = sorted({i.issue_type for i in dataset.issues})
        selected = st.multiselect("Tipi di issue", types, default=types)
        st.caption("I KPI misurano il team, non le singole persone.")

    now = datetime.now(UTC)
    period = period_for_preset(preset, now, settings.tz)
    issues = [i for i in dataset.issues if i.issue_type in selected]
    data = build_dashboard(
        issues,
        dataset.sprints,
        settings.status_mapping_obj(),
        period,
        now=now,
        tz=settings.tz,
        bug_types=settings.bug_types,
    )

    _tiles(data)
    flow, sprint, quality = st.tabs(["Flusso", "Sprint", "Qualità"])
    with flow:
        _flow_tab(data)
    with sprint:
        _sprint_tab(data)
    with quality:
        _quality_tab(data)


main()
