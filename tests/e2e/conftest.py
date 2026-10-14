import os
import socket
import subprocess
import sys
import time
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import httpx
import pytest

DASHBOARD = Path(__file__).parents[2] / "src" / "jira_kpi" / "app" / "dashboard.py"
CHROMIUM = Path("/opt/pw-browsers/chromium")


@pytest.fixture(scope="session")
def browser_type_launch_args(browser_type_launch_args: dict[str, Any]) -> dict[str, Any]:
    # Usa il Chromium preinstallato se presente (evita download in CI/container).
    if CHROMIUM.exists():
        return {**browser_type_launch_args, "executable_path": str(CHROMIUM)}
    return browser_type_launch_args


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port: int = s.getsockname()[1]
        return port


@pytest.fixture(scope="session")
def dashboard_url(tmp_path_factory: pytest.TempPathFactory) -> Iterator[str]:
    port = _free_port()
    env = {
        **os.environ,
        "JIRA_KPI_DEMO": "1",
        "JIRA_KPI_DEMO_DB": str(tmp_path_factory.mktemp("e2e") / "demo.sqlite"),
    }
    log_path = tmp_path_factory.mktemp("e2e-log") / "streamlit.log"
    with log_path.open("w") as log:
        proc = subprocess.Popen(
            [
                sys.executable,
                "-m",
                "streamlit",
                "run",
                str(DASHBOARD),
                "--server.headless=true",
                f"--server.port={port}",
                "--browser.gatherUsageStats=false",
            ],
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            yield _wait_until_healthy(proc, f"http://127.0.0.1:{port}", log_path)
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()


def _wait_until_healthy(proc: subprocess.Popen[bytes], url: str, log_path: Path) -> str:
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            pytest.fail(f"dashboard terminata (exit {proc.returncode}):\n{log_path.read_text()}")
        try:
            if httpx.get(f"{url}/_stcore/health", timeout=1).status_code == 200:
                return url
        except httpx.HTTPError:
            pass
        time.sleep(0.5)
    pytest.fail(f"la dashboard non si è avviata entro 60s:\n{log_path.read_text()}")
