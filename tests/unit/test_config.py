from pathlib import Path

import pytest
from pydantic import ValidationError

from jira_kpi.config import JiraCredentials, Settings, load_settings
from jira_kpi.domain.models import StatusCategory

BASE = {
    "jira_url": "https://acme.atlassian.net/",
    "project": "PAY",
    "team": "8c2f-team-uuid",
    "status_mapping": {"In Progress": "in_progress", "Done": "done"},
}


class TestJql:
    def test_built_from_project_and_team(self) -> None:
        settings = Settings.model_validate(BASE)
        assert settings.jql == 'project = "PAY" AND "Team[Team]" = "8c2f-team-uuid"'

    def test_values_are_escaped(self) -> None:
        settings = Settings.model_validate({**BASE, "project": 'P"A\\Y'})
        assert settings.jql.startswith('project = "P\\"A\\\\Y"')

    def test_custom_team_field(self) -> None:
        settings = Settings.model_validate({**BASE, "team_field": "labels", "team": "squad-a"})
        assert settings.jql == 'project = "PAY" AND "labels" = "squad-a"'

    def test_override(self) -> None:
        settings = Settings.model_validate({**BASE, "jql_override": "filter = 123"})
        assert settings.jql == "filter = 123"

    def test_order_by_is_rejected(self) -> None:
        with pytest.raises(ValidationError, match="ORDER BY"):
            Settings.model_validate({**BASE, "jql_override": "project = X order by created"})


class TestSettings:
    def test_url_is_normalized(self) -> None:
        assert Settings.model_validate(BASE).jira_url == "https://acme.atlassian.net"

    def test_http_url_rejected(self) -> None:
        with pytest.raises(ValidationError, match="https"):
            Settings.model_validate({**BASE, "jira_url": "http://acme.atlassian.net"})

    def test_status_mapping(self) -> None:
        mapping = Settings.model_validate(BASE).status_mapping_obj()
        assert mapping.category("done") is StatusCategory.DONE
        assert mapping.category("Unknown") is StatusCategory.TODO

    def test_invalid_timezone(self) -> None:
        with pytest.raises(ValidationError, match="timezone"):
            Settings.model_validate({**BASE, "timezone": "Mars/Base"})

    def test_load_from_yaml(self, tmp_path: Path) -> None:
        path = tmp_path / "config.yaml"
        path.write_text(
            "jira_url: https://acme.atlassian.net\nproject: PAY\nteam: t1\n"
            "status_mapping:\n  Done: done\n"
        )
        settings = load_settings(path)
        assert settings.project == "PAY"
        assert settings.timezone == "Europe/Rome"


class TestCredentials:
    def test_from_environment(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("JIRA_EMAIL", "dev@acme.test")
        monkeypatch.setenv("JIRA_API_TOKEN", "s3cr3t")
        creds = JiraCredentials()  # type: ignore[call-arg]
        assert creds.email == "dev@acme.test"
        assert creds.api_token.get_secret_value() == "s3cr3t"
        assert "s3cr3t" not in repr(creds)
