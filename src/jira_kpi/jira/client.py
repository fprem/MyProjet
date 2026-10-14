"""Client minimale per l'API REST di Jira Cloud (sola lettura)."""

from __future__ import annotations

import time
from collections.abc import Callable, Iterator
from types import TracebackType
from typing import Any

import httpx

RETRYABLE = {429, 500, 502, 503, 504}
PAGE_SIZE = 100


class JiraError(RuntimeError):
    pass


class JiraAuthError(JiraError):
    pass


def _error_detail(response: httpx.Response) -> str:
    try:
        body = response.json()
    except ValueError:
        return response.text[:200]
    if isinstance(body, dict):
        messages = list(body.get("errorMessages") or []) + list((body.get("errors") or {}).values())
        return "; ".join(str(m) for m in messages)
    return ""


class JiraClient:
    def __init__(
        self,
        base_url: str,
        email: str,
        api_token: str,
        *,
        timeout: float = 30.0,
        max_retries: int = 4,
        backoff: float = 1.0,
        sleep: Callable[[float], None] = time.sleep,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._http = httpx.Client(
            base_url=base_url.rstrip("/"),
            auth=(email, api_token),
            timeout=timeout,
            headers={"Accept": "application/json"},
            transport=transport,
        )
        self._max_retries = max_retries
        self._backoff = backoff
        self._sleep = sleep

    def __repr__(self) -> str:
        return f"JiraClient(base_url={str(self._http.base_url)!r})"

    def __enter__(self) -> JiraClient:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()

    def close(self) -> None:
        self._http.close()

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        for attempt in range(self._max_retries + 1):
            last_attempt = attempt == self._max_retries
            try:
                response = self._http.request(method, path, **kwargs)
            except httpx.TransportError as exc:
                if last_attempt:
                    raise JiraError(f"errore di rete verso Jira: {exc}") from exc
                self._sleep(self._backoff * 2**attempt)
                continue
            if response.status_code in (401, 403):
                raise JiraAuthError(
                    f"Jira ha rifiutato le credenziali ({response.status_code}): "
                    "verificare JIRA_EMAIL, JIRA_API_TOKEN e i permessi sul progetto"
                )
            if response.status_code in RETRYABLE and not last_attempt:
                retry_after = response.headers.get("Retry-After")
                delay = float(retry_after) if retry_after else self._backoff * 2**attempt
                self._sleep(delay)
                continue
            if response.is_error:
                raise JiraError(
                    f"{method} {path} -> {response.status_code}: {_error_detail(response)}"
                )
            return response.json()
        raise AssertionError("unreachable")  # pragma: no cover

    def search_issues(self, jql: str, fields: list[str]) -> Iterator[dict[str, Any]]:
        """Issue che soddisfano la JQL, con changelog (endpoint `/search/jql`)."""
        body: dict[str, Any] = {
            "jql": jql,
            "fields": fields,
            "expand": "changelog",
            "maxResults": PAGE_SIZE,
        }
        while True:
            page = self._request("POST", "/rest/api/3/search/jql", json=body)
            yield from page.get("issues", [])
            token = page.get("nextPageToken")
            if page.get("isLast") or not token:
                return
            body = {**body, "nextPageToken": token}

    def get_changelog(self, key: str) -> list[dict[str, Any]]:
        """Changelog completo di una issue (la ricerca ne restituisce al massimo 100 voci)."""
        histories: list[dict[str, Any]] = []
        start = 0
        while True:
            page = self._request(
                "GET",
                f"/rest/api/3/issue/{key}/changelog",
                params={"startAt": start, "maxResults": PAGE_SIZE},
            )
            values = page.get("values", [])
            histories.extend(values)
            if page.get("isLast", True) or not values:
                return histories
            start += len(values)

    def get_fields(self) -> list[dict[str, Any]]:
        result: list[dict[str, Any]] = self._request("GET", "/rest/api/3/field")
        return result
