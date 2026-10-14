import json
from collections.abc import Iterator

import httpx
import pytest
import respx

from jira_kpi.jira.client import JiraAuthError, JiraClient, JiraError

BASE = "https://acme.atlassian.net"


@pytest.fixture
def sleeps() -> list[float]:
    return []


@pytest.fixture
def client(sleeps: list[float]) -> Iterator[JiraClient]:
    with JiraClient(BASE, "dev@acme.test", "tok", sleep=sleeps.append, max_retries=2) as c:
        yield c


@respx.mock
def test_search_paginates_with_next_page_token(client: JiraClient) -> None:
    route = respx.post(f"{BASE}/rest/api/3/search/jql").mock(
        side_effect=[
            httpx.Response(200, json={"issues": [{"key": "A-1"}], "nextPageToken": "p2"}),
            httpx.Response(200, json={"issues": [{"key": "A-2"}], "isLast": True}),
        ]
    )
    keys = [i["key"] for i in client.search_issues("project = A", ["status"])]
    assert keys == ["A-1", "A-2"]
    first, second = (json.loads(c.request.content) for c in route.calls)
    assert first == {
        "jql": "project = A",
        "fields": ["status"],
        "expand": "changelog",
        "maxResults": 100,
    }
    assert second["nextPageToken"] == "p2"


@respx.mock
def test_uses_basic_auth(client: JiraClient) -> None:
    route = respx.post(f"{BASE}/rest/api/3/search/jql").mock(
        return_value=httpx.Response(200, json={"issues": [], "isLast": True})
    )
    list(client.search_issues("x", []))
    assert route.calls[0].request.headers["Authorization"].startswith("Basic ")


@respx.mock
def test_get_changelog_paginates(client: JiraClient) -> None:
    respx.get(f"{BASE}/rest/api/3/issue/A-1/changelog").mock(
        side_effect=[
            httpx.Response(200, json={"values": [{"id": "1"}], "startAt": 0, "isLast": False}),
            httpx.Response(200, json={"values": [{"id": "2"}], "startAt": 1, "isLast": True}),
        ]
    )
    assert [h["id"] for h in client.get_changelog("A-1")] == ["1", "2"]
    assert respx.calls[1].request.url.params["startAt"] == "1"


@respx.mock
def test_retries_on_429_honouring_retry_after(client: JiraClient, sleeps: list[float]) -> None:
    respx.get(f"{BASE}/rest/api/3/field").mock(
        side_effect=[
            httpx.Response(429, headers={"Retry-After": "7"}),
            httpx.Response(503),
            httpx.Response(200, json=[{"id": "customfield_10016", "name": "Story Points"}]),
        ]
    )
    assert client.get_fields()[0]["name"] == "Story Points"
    assert sleeps == [7.0, 2.0]  # Retry-After, poi backoff esponenziale (1 * 2**1)


@respx.mock
def test_gives_up_after_max_retries(client: JiraClient) -> None:
    respx.get(f"{BASE}/rest/api/3/field").mock(return_value=httpx.Response(500))
    with pytest.raises(JiraError, match="500"):
        client.get_fields()


@respx.mock
@pytest.mark.parametrize("status", [401, 403])
def test_auth_errors_are_not_retried(client: JiraClient, status: int) -> None:
    route = respx.get(f"{BASE}/rest/api/3/field").mock(return_value=httpx.Response(status))
    with pytest.raises(JiraAuthError):
        client.get_fields()
    assert route.call_count == 1


@respx.mock
def test_client_error_includes_jira_message(client: JiraClient) -> None:
    respx.post(f"{BASE}/rest/api/3/search/jql").mock(
        return_value=httpx.Response(400, json={"errorMessages": ["Campo 'Team' inesistente"]})
    )
    with pytest.raises(JiraError, match="Team"):
        list(client.search_issues("bad", []))


@respx.mock
def test_network_errors_are_retried_then_wrapped(client: JiraClient) -> None:
    respx.get(f"{BASE}/rest/api/3/field").mock(side_effect=httpx.ConnectTimeout("boom"))
    with pytest.raises(JiraError, match="boom"):
        client.get_fields()


def test_token_not_in_repr() -> None:
    with JiraClient(BASE, "dev@acme.test", "super-secret") as c:
        assert "super-secret" not in repr(c)
