"""Dati demo realistici in formato JSON Jira, per provare la dashboard senza un'istanza Jira."""

from __future__ import annotations

import random
from datetime import datetime, time, timedelta
from pathlib import Path
from typing import Any

from jira_kpi.config import Settings
from jira_kpi.domain.models import StatusCategory, StatusMapping
from jira_kpi.storage.repository import IssueRepository

SP_FIELD = "customfield_10016"
SPRINT_FIELD = "customfield_10020"
SPRINT_LENGTH = timedelta(days=14)
# Incrementare quando cambia il generatore: i DB demo esistenti verranno rigenerati.
DEMO_VERSION = "2"
DEMO_MAX_AGE = timedelta(days=1)

DEMO_STATUS_MAPPING = {
    "To Do": StatusCategory.TODO,
    "In Progress": StatusCategory.IN_PROGRESS,
    "Code Review": StatusCategory.IN_PROGRESS,
    "Waiting for QA": StatusCategory.WAITING,
    "Done": StatusCategory.DONE,
}
DEMO_MAPPING = StatusMapping(DEMO_STATUS_MAPPING)


def demo_settings(db_path: str = "data/demo.sqlite") -> Settings:
    return Settings(
        jira_url="https://demo.atlassian.net",
        project="DEMO",
        team="demo-team",
        timezone="Europe/Rome",
        db_path=db_path,
        status_mapping=DEMO_STATUS_MAPPING,
    )


def ensure_demo_db(path: str | Path, now: datetime) -> bool:
    """Crea o rigenera il DB demo se manca, è di una versione precedente o è scaduto.

    Ritorna True se il DB è stato (ri)generato.
    """
    with IssueRepository(path) as repo:
        last = repo.last_sync()
        if (
            repo.count()
            and repo.get_meta("demo_version") == DEMO_VERSION
            and last is not None
            and now - last < DEMO_MAX_AGE
        ):
            return False
    write_demo_db(path, now)
    return True


def write_demo_db(path: str | Path, now: datetime) -> int:
    """Sovrascrive il DB con dati demo freschi. Ritorna il numero di issue."""
    with IssueRepository(path) as repo:
        repo.clear()
        repo.upsert(generate_raw_issues(now))
        repo.set_last_sync(now)
        repo.set_meta("demo_version", DEMO_VERSION)
        return repo.count()


def _fmt(at: datetime) -> str:
    return at.strftime("%Y-%m-%dT%H:%M:%S.000%z")


def _ids(ids: list[int]) -> str | None:
    return ", ".join(str(i) for i in ids) or None


def _sprints(now: datetime, count: int) -> list[dict[str, Any]]:
    monday = datetime.combine((now - timedelta(days=now.weekday())).date(), time(9), now.tzinfo)
    first_start = monday - timedelta(days=7) - (count - 1) * SPRINT_LENGTH
    sprints = []
    for n in range(count):
        start = first_start + n * SPRINT_LENGTH
        end = start + SPRINT_LENGTH
        sprint: dict[str, Any] = {
            "id": 100 + n,
            "name": f"DEMO Sprint {n + 1}",
            "state": "closed" if end <= now else "active",
            "boardId": 1,
            "startDate": _fmt(start),
            "endDate": _fmt(end),
        }
        if end <= now:
            sprint["completeDate"] = _fmt(end + timedelta(hours=1))
        sprints.append(sprint)
    return sprints


def generate_raw_issues(
    now: datetime, *, seed: int = 7, sprint_count: int = 14
) -> list[dict[str, Any]]:
    rng = random.Random(seed)
    sprints = _sprints(now, sprint_count)
    starts = [datetime.fromisoformat(s["startDate"]) for s in sprints]
    raws: list[dict[str, Any]] = []

    def days(low: float, high: float) -> timedelta:
        return timedelta(days=rng.uniform(low, high))

    for idx, sprint_start in enumerate(starts):
        for _ in range(rng.randint(9, 13)):
            key = f"DEMO-{len(raws) + 1}"
            issue_type = "Bug" if rng.random() < 0.2 else rng.choice(["Story", "Story", "Task"])
            points = (
                None
                if issue_type == "Bug" and rng.random() < 0.3
                else rng.choice([1, 2, 3, 3, 5, 5, 8])
            )
            added_mid = rng.random() < 0.15
            joined = sprint_start + (days(1, 7) if added_mid else -timedelta(hours=2))
            created = joined - (days(0, 3) if issue_type == "Bug" else days(1, 25))

            # (istante, campo, from, to)
            events: list[tuple[datetime, str, str | None, str | None]] = []
            membership = [sprints[idx]["id"]]
            events.append((joined, "Sprint", None, _ids(membership)))

            if rng.random() < 0.05:  # rimossa dallo sprint, mai lavorata
                events.append((joined + days(1, 3), "Sprint", _ids(membership), None))
                membership = []
            else:
                size = points or 2
                at = max(joined, sprint_start) + days(0, 5 + size / 4)
                path = [
                    ("In Progress", days(0.5, 1.2 * (1 + size))),
                    ("Code Review", days(0.2, 2)),
                ]
                if rng.random() > 0.1:
                    path.append(("Waiting for QA", days(0.2, 3)))
                if rng.random() < 0.08:  # riaperta dopo il completamento
                    path += [("Done", days(0.5, 2)), ("In Progress", days(0.5, 2))]
                path.append(("Done", timedelta()))
                previous = "To Do"
                for status, stay in path:
                    events.append((at, "status", previous, status))
                    previous, at = status, at + stay
                done_at = events[-1][0]
                # carry-over: Jira aggiunge lo sprint successivo alla chiusura
                current = idx
                while current + 1 < len(sprints):
                    end = starts[current] + SPRINT_LENGTH
                    if done_at <= end:
                        break
                    before = list(membership)
                    membership.append(sprints[current + 1]["id"])
                    events.append(
                        (end + timedelta(hours=1), "Sprint", _ids(before), _ids(membership))
                    )
                    current += 1

            raws.append(_to_raw(key, issue_type, points, created, events, sprints, now))
    return [r for r in raws if datetime.fromisoformat(r["fields"]["created"]) <= now]


def _to_raw(
    key: str,
    issue_type: str,
    points: int | None,
    created: datetime,
    events: list[tuple[datetime, str, str | None, str | None]],
    sprints: list[dict[str, Any]],
    now: datetime,
) -> dict[str, Any]:
    past = sorted((e for e in events if e[0] <= now), key=lambda e: e[0])
    status = "To Do"
    sprint_ids: set[int] = set()
    histories = []
    for n, (at, field, from_value, to_value) in enumerate(past):
        if field == "status":
            item = {
                "field": "status",
                "fieldId": "status",
                "fromString": from_value,
                "toString": to_value,
            }
            status = to_value or status
        else:
            item = {"field": "Sprint", "fieldId": SPRINT_FIELD, "from": from_value, "to": to_value}
            sprint_ids = {int(i) for i in (to_value or "").split(",") if i.strip()}
        histories.append({"id": str(n + 1), "created": _fmt(at), "items": [item]})
    by_id = {s["id"]: s for s in sprints}
    return {
        "key": key,
        "fields": {
            "summary": f"Attività demo {key}",
            "issuetype": {"name": issue_type},
            "status": {"name": status},
            "priority": {"name": "High" if key.endswith(("3", "7")) else "Medium"},
            "created": _fmt(created),
            "updated": _fmt(past[-1][0] if past else created),
            SP_FIELD: points,
            SPRINT_FIELD: [by_id[i] for i in sorted(sprint_ids)] or None,
        },
        "changelog": {"histories": histories, "total": len(histories)},
    }
