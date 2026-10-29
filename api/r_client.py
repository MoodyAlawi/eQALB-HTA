"""Persistent bridge between FastAPI and the eQalb R model.

The R model (eqalb_markov.R, eqalb_owsa.R, eqalb_survival.R) is the single
source of truth for every number this API returns. It is reached through
api/r_worker.R, a long-lived Rscript process that speaks a JSON-lines protocol
on stdin/stdout and serves the route handlers of api/plumber.R. Nothing in this
module computes or re-implements model output; it only transports requests and
responses and keeps the worker processes healthy.
"""

from __future__ import annotations

import atexit
import json
import logging
import os
import queue
import shutil
import subprocess
import threading
import time
from pathlib import Path
from typing import Any

LOGGER = logging.getLogger("eqalb.r_model")

API_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = API_DIR.parent
WORKER_SCRIPT = API_DIR / "r_worker.R"

# Windows installs of R are not always on PATH, so well-known locations are
# searched before giving up.
RSCRIPT_FALLBACK_GLOB = "R-*/bin/Rscript.exe"
RSCRIPT_SEARCH_DIRS = (
    Path("C:/Program Files/R"),
    Path("C:/Program Files (x86)/R"),
)


class RModelError(RuntimeError):
    """The R model rejected the request (bad or missing input)."""


class RModelUnavailable(RuntimeError):
    """The R model could not be reached at all (missing R, worker died)."""


class RModelTimeout(RModelUnavailable):
    """A request got no answer in time; its worker was discarded, not reused."""


def find_rscript() -> str:
    """Locate the Rscript executable used to start workers."""
    configured = os.environ.get("EQALB_RSCRIPT")
    if configured:
        if Path(configured).exists() or shutil.which(configured):
            return configured
        raise RModelUnavailable(
            f"EQALB_RSCRIPT points to '{configured}', which does not exist."
        )

    found = shutil.which("Rscript")
    if found:
        return found

    candidates: list[Path] = []
    for directory in RSCRIPT_SEARCH_DIRS:
        if directory.is_dir():
            candidates.extend(sorted(directory.glob(RSCRIPT_FALLBACK_GLOB), reverse=True))
    if candidates:
        return str(candidates[0])

    raise RModelUnavailable(
        "Rscript was not found. Install R, or set the EQALB_RSCRIPT environment "
        "variable to the full path of Rscript.exe."
    )


class RWorker:
    """One Rscript process running api/r_worker.R."""

    def __init__(self, rscript: str, timeout: float) -> None:
        self.timeout = timeout
        self.endpoints: list[str] = []
        self.worker_pid: int | None = None
        self.started_at = time.time()

        self._process = subprocess.Popen(
            [rscript, str(WORKER_SCRIPT)],
            cwd=str(PROJECT_ROOT),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        self._lock = threading.Lock()
        self._lines: queue.Queue[str | None] = queue.Queue()
        self._next_id = 0
        self._closed = False

        for target, stream in (
            (self._read_stdout, self._process.stdout),
            (self._drain_stderr, self._process.stderr),
        ):
            thread = threading.Thread(target=target, args=(stream,), daemon=True)
            thread.start()

        try:
            ready = self._await_message(timeout=timeout)
        except BaseException as error:
            # A worker that never became ready is not left running. It ran no
            # analysis, so a start-up timeout stays an ordinary unavailability that
            # the pool may retry once on a fresh worker.
            self.close(force=True)
            if isinstance(error, RModelTimeout):
                raise RModelUnavailable(str(error)) from error
            raise
        self.endpoints = list(ready.get("endpoints", []))
        self.worker_pid = ready.get("worker_pid")
        LOGGER.info(
            "R worker ready (pid %s, %d endpoints)", self.worker_pid, len(self.endpoints)
        )

    # --- streams ------------------------------------------------------------

    def _read_stdout(self, stream: Any) -> None:
        try:
            for line in stream:
                self._lines.put(line)
        except ValueError:  # stream closed
            pass
        finally:
            self._lines.put(None)

    def _drain_stderr(self, stream: Any) -> None:
        # The R worker forwards model progress printing here; draining the pipe
        # keeps it from filling up and blocking the worker.
        try:
            for line in stream:
                text = line.rstrip()
                if text:
                    LOGGER.debug("r_worker: %s", text)
        except ValueError:
            pass

    def _await_message(self, timeout: float) -> dict[str, Any]:
        """Return the next protocol object, skipping non-JSON output.

        R's project .Rprofile and package loaders may print to stdout before the
        worker takes over (renv and heemod warnings, for example), so anything
        that is not a JSON object is logged and ignored.
        """
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RModelTimeout(
                    f"The R model did not answer within {timeout:.0f} seconds."
                )
            try:
                line = self._lines.get(timeout=min(remaining, 5.0))
            except queue.Empty:
                if self._process.poll() is not None and self._lines.empty():
                    raise RModelUnavailable(self._death_reason()) from None
                continue

            if line is None:
                raise RModelUnavailable(self._death_reason())
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                LOGGER.debug("ignoring non-protocol output: %s", line[:400])
                continue
            if isinstance(message, dict):
                return message
            LOGGER.debug("ignoring non-object protocol line: %s", line[:400])

    def _death_reason(self) -> str:
        code = self._process.poll()
        return (
            "The R model worker stopped unexpectedly"
            + (f" (exit code {code})" if code is not None else "")
            + ". Check that the eQalb R packages are installed."
        )

    # --- requests -----------------------------------------------------------

    def request(
        self, endpoint: str, query: dict[str, str] | None, body: dict[str, Any] | None
    ) -> dict[str, Any]:
        payload = {
            "id": self._next_id,
            "endpoint": endpoint,
            "query": query or {},
            "body": body or {},
        }
        with self._lock:
            self._next_id += 1
            if self._closed:
                raise RModelUnavailable("The R model worker is not running.")
            if self._process.poll() is not None:
                raise RModelUnavailable(self._death_reason())

            assert self._process.stdin is not None
            try:
                self._process.stdin.write(json.dumps(payload) + "\n")
                self._process.stdin.flush()
            except (BrokenPipeError, OSError) as error:
                raise RModelUnavailable(self._death_reason()) from error

            try:
                message = self._await_message(self.timeout)
            except RModelUnavailable:
                # A timed-out worker is still busy with this request and would answer
                # it later, in place of the next one, so it is never used again.
                self.close(force=True)
                raise

        if message.get("id") != payload["id"]:
            # Replies can no longer be matched to requests on this stream.
            self.close(force=True)
            raise RModelUnavailable(
                "The R model answered out of order; the worker was discarded."
            )
        if message.get("ok") is not True:
            raise RModelError(str(message.get("error", "The R model failed.")))
        result = message.get("result")
        return result if isinstance(result, dict) else {"value": result}

    # --- lifecycle ----------------------------------------------------------

    @property
    def alive(self) -> bool:
        return not self._closed and self._process.poll() is None

    def close(self, force: bool = False) -> None:
        """Stop the worker; ``force`` kills it rather than letting it finish.

        It runs while another error is being reported, so a pipe or process error
        here is contained: it can neither skip the kill nor replace that error.
        """
        self._closed = True
        process = self._process
        # Closed even when the worker has already exited, so its pipe is released.
        if process.stdin is not None:
            try:
                process.stdin.close()
            except Exception:  # noqa: BLE001 - without end-of-input, it must be killed
                force = True
        if process.poll() is None:
            try:
                if force:
                    process.kill()
                process.wait(timeout=10)
            except (subprocess.TimeoutExpired, OSError):
                try:
                    process.kill()
                    process.wait(timeout=10)
                except (subprocess.TimeoutExpired, OSError) as error:
                    LOGGER.error("R worker pid %s could not be stopped: %s", process.pid, error)
                    # Its reader threads hold the stream locks until the worker
                    # exits, so closing the streams now would block.
                    return
        for stream in (process.stdout, process.stderr):
            try:
                if stream is not None:
                    stream.close()
            except OSError:
                pass


class RModelPool:
    """A small pool of R workers.

    One worker cannot serve two requests at once (R is single-threaded), so the
    pool serialises per worker and lets independent analyses run side by side.
    Requests are pure functions of their inputs, so a request that dies with its
    worker is retried once on a fresh one. A request that times out is not: its
    worker is discarded and the error is returned.
    """

    def __init__(self, size: int, timeout: float | None = None) -> None:
        self.size = max(1, size)
        self.timeout = timeout if timeout is not None else float(
            os.environ.get("EQALB_R_TIMEOUT", "900")
        )
        self._rscript = find_rscript()
        self._slot_ids = list(range(self.size))
        self._slots: queue.Queue[int] = queue.Queue()
        for slot in self._slot_ids:
            self._slots.put(slot)
        self._workers: dict[int, RWorker] = {}
        self._lock = threading.Lock()
        self._closed = False
        self.startup_error: str | None = None

    # --- worker management --------------------------------------------------

    def _worker_for(self, slot: int) -> RWorker:
        worker = self._workers.get(slot)
        if worker is not None and worker.alive:
            return worker
        if worker is not None:
            worker.close()
        with self._lock:
            if self._closed:
                raise RModelUnavailable("The model API is shutting down.")
            worker = RWorker(self._rscript, self.timeout)
            self._workers[slot] = worker
            return worker

    def warmup(self) -> None:
        """Start every worker ahead of the first request."""
        for slot in self._slot_ids:
            try:
                self._worker_for(slot)
            except Exception as error:  # noqa: BLE001 - reported through health
                self.startup_error = str(error)
                LOGGER.warning("Warming up R worker %s failed: %s", slot, error)
                return

    # --- requests -----------------------------------------------------------

    def request(
        self, endpoint: str, query: dict[str, str] | None = None, body: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        try:
            slot = self._slots.get(timeout=self.timeout)
        except queue.Empty:
            raise RModelUnavailable(
                "All model workers are busy; try again when the running analysis finishes."
            ) from None

        try:
            last_error: Exception | None = None
            for attempt in range(2):
                try:
                    return self._worker_for(slot).request(endpoint, query, body)
                except RModelTimeout as error:
                    # Not replayed: the analysis itself may be what took too long.
                    # The worker was discarded, so the slot starts a fresh one next.
                    LOGGER.warning(
                        "R worker slot %s timed out on %s: %s", slot, endpoint, error
                    )
                    raise
                except RModelUnavailable as error:
                    last_error = error
                    LOGGER.warning(
                        "R worker slot %s failed on %s (attempt %d): %s",
                        slot, endpoint, attempt + 1, error,
                    )
            assert last_error is not None
            raise last_error
        finally:
            self._slots.put(slot)

    # --- reporting and lifecycle -------------------------------------------

    def status(self) -> dict[str, Any]:
        ready = [slot for slot, worker in self._workers.items() if worker.alive]
        endpoints: list[str] = []
        for worker in self._workers.values():
            if worker.alive:
                endpoints = worker.endpoints
                break
        return {
            "configured_workers": self.size,
            "ready_workers": len(ready),
            "rscript": self._rscript,
            "endpoints": endpoints,
            "startup_error": self.startup_error,
        }

    def close(self) -> None:
        self._closed = True
        with self._lock:
            for worker in self._workers.values():
                worker.close()
            self._workers.clear()


def create_pool() -> RModelPool:
    size = int(os.environ.get("EQALB_R_WORKERS", "2"))
    pool = RModelPool(size)
    atexit.register(pool.close)
    return pool
