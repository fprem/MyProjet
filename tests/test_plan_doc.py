"""Il piano del progetto (docs/PLAN.md) deve esistere e restare completo."""

from pathlib import Path

PLAN = Path(__file__).resolve().parents[1] / "docs" / "PLAN.md"

REQUIRED_SECTIONS = [
    "## Obiettivo",
    "## Stato attuale del repository",
    "## Regole di lavoro",
    "## Fasi",
    "## Decisioni prese",
    "## Domande aperte",
]


def test_plan_exists():
    assert PLAN.is_file()


def test_plan_has_required_sections():
    text = PLAN.read_text(encoding="utf-8")
    missing = [s for s in REQUIRED_SECTIONS if s not in text]
    assert not missing, f"Sezioni mancanti in docs/PLAN.md: {missing}"


def test_every_phase_has_a_status():
    text = PLAN.read_text(encoding="utf-8")
    phases = [line for line in text.splitlines() if line.startswith("### Fase ")]
    assert phases, "Nessuna fase trovata"
    for phase in phases:
        assert "Stato:" in text.split(phase, 1)[1].split("### ", 1)[0], f"{phase} senza 'Stato:'"
