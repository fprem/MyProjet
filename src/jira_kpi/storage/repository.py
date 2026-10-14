"""Snapshot locale (SQLite) del JSON grezzo delle issue Jira.

Si conserva il JSON grezzo, non il modello di dominio: così una modifica alla
configurazione (es. mapping degli stati) non richiede di riscaricare i dati.
"""

from __future__ import annotations

import json
import sqlite3
from collections.abc import Iterable
from datetime import datetime
from pathlib import Path
from types import TracebackType
from typing import Any

_SCHEMA = """
CREATE TABLE IF NOT EXISTS issues (key TEXT PRIMARY KEY, raw TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS meta (name TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


class IssueRepository:
    def __init__(self, path: str | Path) -> None:
        if str(path) != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(path))
        self._conn.executescript(_SCHEMA)

    def __enter__(self) -> IssueRepository:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()

    def close(self) -> None:
        self._conn.close()

    def _get_meta(self, name: str) -> str | None:
        row = self._conn.execute("SELECT value FROM meta WHERE name = ?", (name,)).fetchone()
        return row[0] if row else None

    def _set_meta(self, name: str, value: str) -> None:
        with self._conn:
            self._conn.execute(
                "INSERT INTO meta(name, value) VALUES (?, ?) "
                "ON CONFLICT(name) DO UPDATE SET value = excluded.value",
                (name, value),
            )

    def ensure_scope(self, jql: str) -> bool:
        """Svuota lo snapshot se la JQL è cambiata. Ritorna True se il DB è stato azzerato."""
        if self._get_meta("jql") == jql:
            return False
        self.clear()
        self._set_meta("jql", jql)
        return True

    def clear(self) -> None:
        with self._conn:
            self._conn.execute("DELETE FROM issues")
            self._conn.execute("DELETE FROM meta WHERE name = 'last_sync'")

    def upsert(self, raw_issues: Iterable[dict[str, Any]]) -> None:
        with self._conn:
            self._conn.executemany(
                "INSERT INTO issues(key, raw) VALUES (?, ?) "
                "ON CONFLICT(key) DO UPDATE SET raw = excluded.raw",
                ((r["key"], json.dumps(r)) for r in raw_issues),
            )

    def load_all(self) -> list[dict[str, Any]]:
        rows = self._conn.execute("SELECT raw FROM issues ORDER BY key").fetchall()
        return [json.loads(row[0]) for row in rows]

    def count(self) -> int:
        result: int = self._conn.execute("SELECT COUNT(*) FROM issues").fetchone()[0]
        return result

    def last_sync(self) -> datetime | None:
        value = self._get_meta("last_sync")
        return datetime.fromisoformat(value) if value else None

    def set_last_sync(self, instant: datetime) -> None:
        self._set_meta("last_sync", instant.isoformat())
