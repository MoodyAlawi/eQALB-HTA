"""Launcher for the eQalb model API (FastAPI).

Pinned to http://127.0.0.1:8788 so the Vite dev-server proxy address is stable.
Run it from the project root:

    .\\api\\.venv\\Scripts\\python.exe .\\api\\run_api.py

or in VS Code: Terminal > Run Task > "eQalb: run model API (127.0.0.1:8788)".

The service itself is api/main.py; this file only fixes the address, points the
interpreter at the bundled virtual environment if one exists, and starts the
server. The R model modules are untouched by anything in this file.
"""

from __future__ import annotations

import os
import socket
import sys
from pathlib import Path

API_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = API_DIR.parent

host = os.environ.get("EQALB_API_HOST", "127.0.0.1")
port = int(os.environ.get("EQALB_API_PORT", "8788"))

os.environ.setdefault("EQALB_API_HOST", host)
os.environ.setdefault("EQALB_API_PORT", str(port))

# api/ must be importable for `from r_client import ...`.
if str(API_DIR) not in sys.path:
    sys.path.insert(0, str(API_DIR))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from main import app, main  # noqa: E402  (path set up above)


def port_is_busy() -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex((host, port)) == 0


if __name__ == "__main__":
    if port_is_busy():
        print(
            f"Port {port} is already in use, so the API was not started.\n"
            "The plain plumber service (api/run_api.R) uses the same port; stop it\n"
            "before starting this one. To use a different port instead:\n"
            f'  $env:EQALB_API_PORT = "{port + 1}"; .\\api\\.venv\\Scripts\\python.exe .\\api\\run_api.py',
            file=sys.stderr,
        )
        raise SystemExit(1)
    main()
