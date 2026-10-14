import json
from pathlib import Path
from typing import Any

import pytest

FIXTURES = Path(__file__).parent / "fixtures"


def load_fixture(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((FIXTURES / name).read_text())
    return data


@pytest.fixture
def story_json() -> dict[str, Any]:
    return load_fixture("issue_story.json")


@pytest.fixture
def bug_json() -> dict[str, Any]:
    return load_fixture("issue_bug_minimal.json")
