"""Interfaccia a riga di comando: sync, discover-fields, demo, dashboard."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from collections.abc import Callable, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol

from pydantic import ValidationError

from jira_kpi.config import JiraCredentials, Settings, load_settings
from jira_kpi.demo import write_demo_db
from jira_kpi.jira.client import JiraClient, JiraError
from jira_kpi.storage.repository import IssueRepository
from jira_kpi.sync import IssueSource, sync

FIELD_HINTS = ("story", "point", "sprint", "team", "estimate")
DASHBOARD = Path(__file__).parent / "app" / "dashboard.py"


class CliClient(IssueSource, Protocol):
    def __enter__(self) -> Any: ...

    def __exit__(self, *exc: Any) -> Any: ...

    def get_fields(self) -> list[dict[str, Any]]: ...


ClientFactory = Callable[[Settings], CliClient]


class CliError(Exception):
    pass


def default_client_factory(settings: Settings) -> CliClient:
    try:
        creds = JiraCredentials()  # type: ignore[call-arg]
    except ValidationError as exc:
        raise CliError(
            "credenziali mancanti: impostare JIRA_EMAIL e JIRA_API_TOKEN (env o file .env)"
        ) from exc
    return JiraClient(settings.jira_url, creds.email, creds.api_token.get_secret_value())


def _load(path: str) -> Settings:
    try:
        return load_settings(path)
    except FileNotFoundError as exc:
        raise CliError(f"file di configurazione non trovato: {path}") from exc
    except ValidationError as exc:
        raise CliError(f"configurazione non valida ({path}):\n{exc}") from exc


def _cmd_sync(args: argparse.Namespace, factory: ClientFactory, now: datetime) -> None:
    settings = _load(args.config)
    with factory(settings) as client, IssueRepository(settings.db_path) as repo:
        result = sync(client, repo, settings, now, full=args.full)
    mode = "completa" if result.full else "incrementale"
    print(f"Sync {mode}: {result.fetched} issue scaricate, {result.total} nello snapshot.")


def _cmd_discover(args: argparse.Namespace, factory: ClientFactory) -> None:
    settings = _load(args.config)
    with factory(settings) as client:
        fields = client.get_fields()
    print("Campi custom candidati (usare l'id in config.yaml):")
    for field in fields:
        name = str(field.get("name", ""))
        if field.get("custom") and any(h in name.casefold() for h in FIELD_HINTS):
            print(f"  {field['id']:<22} {name}")


def _cmd_demo(args: argparse.Namespace, now: datetime) -> None:
    count = write_demo_db(args.db, now)
    print(f"Creato database demo con {count} issue: {args.db}")


def _cmd_dashboard(args: argparse.Namespace) -> None:  # pragma: no cover - avvia un processo
    env = {**os.environ}
    if args.demo:
        env["JIRA_KPI_DEMO"] = "1"
    else:
        env["JIRA_KPI_CONFIG"] = args.config
    subprocess.run([sys.executable, "-m", "streamlit", "run", str(DASHBOARD)], env=env, check=False)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="jira-kpi", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_sync = sub.add_parser("sync", help="scarica/aggiorna i dati da Jira")
    p_sync.add_argument("--config", default="config.yaml")
    p_sync.add_argument("--full", action="store_true", help="risincronizza tutto da zero")

    p_fields = sub.add_parser("discover-fields", help="elenca gli id dei campi custom utili")
    p_fields.add_argument("--config", default="config.yaml")

    p_demo = sub.add_parser("demo", help="genera un database con dati demo")
    p_demo.add_argument("--db", default="data/demo.sqlite")

    p_dash = sub.add_parser("dashboard", help="avvia la dashboard Streamlit")
    p_dash.add_argument("--config", default="config.yaml")
    p_dash.add_argument("--demo", action="store_true")
    return parser


def main(
    argv: Sequence[str] | None = None,
    *,
    client_factory: ClientFactory = default_client_factory,
    now: datetime | None = None,
) -> int:
    args = _parser().parse_args(argv)
    now = now or datetime.now(UTC)
    try:
        if args.command == "sync":
            _cmd_sync(args, client_factory, now)
        elif args.command == "discover-fields":
            _cmd_discover(args, client_factory)
        elif args.command == "demo":
            _cmd_demo(args, now)
        else:  # pragma: no cover
            _cmd_dashboard(args)
    except (CliError, JiraError) as exc:
        print(f"Errore: {exc}", file=sys.stderr)
        return 2
    return 0
