"""Configurazione: parametri non segreti da YAML, credenziali da variabili d'ambiente."""

from __future__ import annotations

import re
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import yaml
from pydantic import BaseModel, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from jira_kpi.domain.models import StatusCategory, StatusMapping

_ORDER_BY = re.compile(r"\border\s+by\b", re.IGNORECASE)


def _quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


class Settings(BaseModel):
    jira_url: str
    project: str
    team: str
    team_field: str = "Team[Team]"
    jql_override: str | None = None
    story_points_field: str = "customfield_10016"
    sprint_field: str = "customfield_10020"
    board_id: int | None = None
    bug_types: list[str] = Field(default_factory=lambda: ["Bug"])
    timezone: str = "Europe/Rome"
    db_path: str = "data/jira_kpi.sqlite"
    status_mapping: dict[str, StatusCategory] = Field(default_factory=dict)
    default_category: StatusCategory = StatusCategory.TODO

    @field_validator("jira_url")
    @classmethod
    def _https_only(cls, value: str) -> str:
        if not value.startswith("https://"):
            raise ValueError("jira_url deve usare https")
        return value.rstrip("/")

    @field_validator("timezone")
    @classmethod
    def _valid_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError(f"timezone non valida: {value}") from exc
        return value

    @field_validator("jql_override")
    @classmethod
    def _no_order_by(cls, value: str | None) -> str | None:
        if value and _ORDER_BY.search(value):
            raise ValueError("la JQL non deve contenere ORDER BY")
        return value

    @property
    def jql(self) -> str:
        if self.jql_override:
            return self.jql_override
        return (
            f"project = {_quote(self.project)} AND {_quote(self.team_field)} = {_quote(self.team)}"
        )

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    def status_mapping_obj(self) -> StatusMapping:
        return StatusMapping(self.status_mapping, default=self.default_category)


class JiraCredentials(BaseSettings):
    """Letti da JIRA_EMAIL e JIRA_API_TOKEN (o da un file .env)."""

    model_config = SettingsConfigDict(env_prefix="JIRA_", env_file=".env", extra="ignore")

    email: str
    api_token: SecretStr


def load_settings(path: str | Path) -> Settings:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return Settings.model_validate(data)
