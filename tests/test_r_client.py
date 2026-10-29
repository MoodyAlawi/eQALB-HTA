#!/usr/bin/env python3
"""Recovery tests for the R worker pool in api/r_client.py.

No R is started. Every worker here is a small Python stand-in that speaks the same
JSON-lines protocol as api/r_worker.R: it announces itself with a ready line, then
answers each request line with a reply that carries the request id. Its endpoints
let a test make it answer late, answer with the wrong id, or start slowly, so the
pool's handling of a timed-out or desynchronised worker can be checked directly.

    api/.venv/Scripts/python.exe tests/test_r_client.py   # Windows
    api/.venv/bin/python tests/test_r_client.py           # elsewhere

The script exits non-zero if any check fails.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import textwrap
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

API_DIR = Path(__file__).resolve().parent.parent / "api"
sys.path.insert(0, str(API_DIR))

import r_client  # noqa: E402  (needs the path above)
from r_client import RModelPool, RModelTimeout, RModelUnavailable, RWorker  # noqa: E402

# The stand-in worker. `slow` answers after `seconds`; `wrong_id_once` answers its
# first request with an id that was never sent and behaves normally afterwards;
# every request is appended to the log so a test can count how often it was run.
FAKE_WORKER = textwrap.dedent(
    """
    import json, os, sys, time

    def send(payload):
        sys.stdout.write(json.dumps(payload) + "\\n")
        sys.stdout.flush()

    time.sleep(float(os.environ.get("FAKE_WORKER_STARTUP_DELAY", "0")))
    send({"ready": True, "worker_pid": os.getpid(),
          "endpoints": ["echo", "slow", "wrong_id_once"]})

    log = os.environ["FAKE_WORKER_LOG"]
    marker = os.environ["FAKE_WORKER_MARKER"]
    for line in sys.stdin:
        request = json.loads(line)
        endpoint = request["endpoint"]
        with open(log, "a", encoding="utf-8") as handle:
            handle.write(f"{os.getpid()} {endpoint} {request['id']}\\n")
        reply_id = request["id"]
        if endpoint == "slow":
            time.sleep(float(request["query"].get("seconds", "2")))
        elif endpoint == "wrong_id_once" and not os.path.exists(marker):
            open(marker, "w").close()
            reply_id = request["id"] + 1000
        send({"id": reply_id, "ok": True,
              "result": {"endpoint": endpoint, "id": request["id"],
                         "pid": os.getpid()}})
    """
)

TIMEOUT = 1.0
SLOW_SECONDS = "2"

# A Windows virtual environment's python.exe is a launcher that starts the real
# interpreter as a child, so its pid is not the worker's and killing it would not
# stop the worker. The base interpreter runs the stand-in as one process.
WORKER_PYTHON = getattr(sys, "_base_executable", sys.executable)

# The client names no threads, so its stream readers carry their target's name.
READER_THREAD_SUFFIXES = ("(_read_stdout)", "(_drain_stderr)")


class FailingPipe:
    """A worker's stdin whose close() fails, as a broken pipe's can.

    Writes pass through to the real pipe, so requests still reach the worker.
    """

    def __init__(self, pipe, error: BaseException) -> None:
        self.pipe = pipe
        self.error = error

    def write(self, text: str) -> int:
        return self.pipe.write(text)

    def flush(self) -> None:
        self.pipe.flush()

    def close(self) -> None:
        raise self.error


class WorkerRecoveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.threads_before = set(threading.enumerate())
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        script = tmp / "fake_worker.py"
        script.write_text(FAKE_WORKER, encoding="utf-8")
        self.log = tmp / "requests.log"
        self.log.touch()

        # Every process the client starts is recorded, so cleanup can be checked
        # on the real process handles rather than on the client's own bookkeeping.
        self.processes: list[subprocess.Popen] = []
        real_popen = subprocess.Popen

        def recording_popen(*args, **kwargs):
            process = real_popen(*args, **kwargs)
            self.processes.append(process)
            return process

        self.env = {
            "FAKE_WORKER_LOG": str(self.log),
            "FAKE_WORKER_MARKER": str(tmp / "wrong_id.marker"),
            "FAKE_WORKER_STARTUP_DELAY": "0",
        }
        # Cleanups run last-registered first: a test's own pool or worker close runs
        # before anything here, so the checks below see what close() left behind.
        self.addCleanup(self.tmp.cleanup)
        self.addCleanup(self.assert_reader_threads_finished)
        self.addCleanup(self.assert_no_worker_left_running)
        for patcher in (
            mock.patch.object(r_client, "WORKER_SCRIPT", script),
            mock.patch.object(r_client, "find_rscript", return_value=WORKER_PYTHON),
            mock.patch.object(r_client.subprocess, "Popen", side_effect=recording_popen),
            mock.patch.dict(os.environ, self.env),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def assert_no_worker_left_running(self) -> None:
        # Stops any stand-in still running, so a failure leaves nothing behind, and
        # then fails the test: by now every test has closed what it started.
        left = [process for process in self.processes if process.poll() is None]
        for process in left:
            process.kill()
            process.wait(timeout=10)
        if left:
            self.fail(f"close() left worker(s) {[p.pid for p in left]} running")

    def assert_reader_threads_finished(self) -> None:
        readers = [
            thread
            for thread in set(threading.enumerate()) - self.threads_before
            if thread.name.endswith(READER_THREAD_SUFFIXES)
        ]
        for thread in readers:
            thread.join(timeout=5)
        alive = [thread.name for thread in readers if thread.is_alive()]
        if alive:
            self.fail(f"reader threads still running: {alive}")

    # --- helpers ---------------------------------------------------------------

    def break_stdin_close(self, process: subprocess.Popen, error: BaseException) -> None:
        pipe = process.stdin
        self.addCleanup(pipe.close)
        process.stdin = FailingPipe(pipe, error)

    def requests_seen(self, endpoint: str) -> int:
        lines = self.log.read_text(encoding="utf-8").splitlines()
        return sum(1 for line in lines if line.split()[1] == endpoint)

    def assert_exited(self, process: subprocess.Popen) -> None:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.fail(f"worker process {process.pid} is still running")

    # --- 1. a late reply cannot reach the next request ---------------------------

    def test_timeout_then_late_reply_does_not_contaminate_next_request(self) -> None:
        pool = RModelPool(1, timeout=TIMEOUT)
        self.addCleanup(pool.close)

        with self.assertRaises(RModelUnavailable) as raised:
            pool.request("slow", {"seconds": SLOW_SECONDS})
        self.assertIn("did not answer", str(raised.exception))

        # Give a surviving worker time to write its late reply, so contamination,
        # if it were possible, would be waiting in the stream.
        time.sleep(float(SLOW_SECONDS) + 0.5)

        result = pool.request("echo", {"n": "1"})
        self.assertEqual(result["endpoint"], "echo")
        # The timed-out analysis was not replayed on any worker.
        self.assertEqual(self.requests_seen("slow"), 1)

    def test_timed_out_worker_is_closed(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        self.addCleanup(worker.close)
        process = self.processes[-1]

        with self.assertRaises(RModelUnavailable):
            worker.request("slow", {"seconds": SLOW_SECONDS}, None)

        self.assertFalse(worker.alive)
        self.assert_exited(process)

    # --- 2. a response-id mismatch discards the worker ---------------------------

    def test_id_mismatch_discards_worker(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        self.addCleanup(worker.close)
        process = self.processes[-1]

        with self.assertRaises(RModelUnavailable) as raised:
            worker.request("wrong_id_once", None, None)
        self.assertIn("out of order", str(raised.exception))

        self.assertFalse(worker.alive)
        self.assert_exited(process)

    # --- 3. the next request runs on a healthy replacement -----------------------

    def test_mismatch_is_retried_on_a_replacement_worker(self) -> None:
        pool = RModelPool(1, timeout=TIMEOUT)
        self.addCleanup(pool.close)

        result = pool.request("wrong_id_once")

        self.assertEqual(result["endpoint"], "wrong_id_once")
        self.assertEqual(len(self.processes), 2)
        first, replacement = self.processes
        self.assertEqual(result["pid"], replacement.pid)
        self.assert_exited(first)
        self.assertEqual(pool.status()["ready_workers"], 1)

    def test_request_after_timeout_uses_a_replacement_worker(self) -> None:
        pool = RModelPool(1, timeout=TIMEOUT)
        self.addCleanup(pool.close)
        pool.warmup()
        first = self.processes[0]

        with self.assertRaises(RModelUnavailable):
            pool.request("slow", {"seconds": SLOW_SECONDS})
        self.assert_exited(first)
        self.assertEqual(pool.status()["ready_workers"], 0)

        result = pool.request("echo")
        self.assertNotEqual(result["pid"], first.pid)
        self.assertEqual(pool.status()["ready_workers"], 1)

    # --- 4. ordinary requests are unchanged --------------------------------------

    def test_ordinary_requests_reuse_their_worker(self) -> None:
        pool = RModelPool(2, timeout=TIMEOUT)
        self.addCleanup(pool.close)
        pool.warmup()

        pids = {pool.request("echo", {"n": str(n)})["pid"] for n in range(6)}

        self.assertEqual(len(self.processes), 2)
        self.assertLessEqual(pids, {process.pid for process in self.processes})
        self.assertEqual(pool.status()["ready_workers"], 2)

    # --- 5. nothing is left running ----------------------------------------------

    def test_pool_close_leaves_no_worker_running(self) -> None:
        pool = RModelPool(2, timeout=TIMEOUT)
        pool.warmup()
        with self.assertRaises(RModelUnavailable):
            pool.request("slow", {"seconds": SLOW_SECONDS})
        # Slots are handed out in turn, so the second request reaches the slot whose
        # worker was discarded and starts its replacement.
        pool.request("echo")
        pool.request("echo")
        pool.close()

        self.assertGreaterEqual(len(self.processes), 3)
        for process in self.processes:
            self.assert_exited(process)

    def test_worker_that_never_becomes_ready_is_closed(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_WORKER_STARTUP_DELAY": "3"}):
            with self.assertRaises(RModelUnavailable):
                RWorker(WORKER_PYTHON, TIMEOUT)

        self.assertEqual(len(self.processes), 1)
        self.assert_exited(self.processes[0])

    # --- 6. a failure while closing cannot skip the kill or hide the timeout -----
    #
    # `returncode` is read directly, never through poll(): it is set only once the
    # process has been waited for, so it shows whether close() itself waited.

    def test_timeout_survives_a_failing_stdin_close(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        process = self.processes[-1]
        self.break_stdin_close(process, BrokenPipeError(32, "Broken pipe"))

        with self.assertRaises(RModelTimeout):
            worker.request("slow", {"seconds": SLOW_SECONDS}, None)

        self.assertIsNotNone(process.returncode, "close() did not wait for the worker")

    def test_close_survives_an_unexpected_stdin_error(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        process = self.processes[-1]
        self.break_stdin_close(process, RuntimeError("pipe close failed"))

        # Graceful: the worker never sees end-of-input, so it has to be killed.
        worker.close()

        self.assertIsNotNone(process.returncode, "close() did not stop the worker")

    def test_close_waits_again_when_the_first_wait_times_out(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        process = self.processes[-1]
        real_wait = process.wait
        waits: list[float | None] = []

        def wait(timeout=None):
            waits.append(timeout)
            if len(waits) == 1:
                raise subprocess.TimeoutExpired(process.args, timeout)
            return real_wait(timeout=timeout)

        process.wait = wait
        worker.close(force=True)

        self.assertEqual(len(waits), 2)
        self.assertIsNotNone(process.returncode, "close() did not wait after the kill")

    def test_timeout_survives_a_failing_kill(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        process = self.processes[-1]
        real_kill = process.kill
        process.kill = mock.Mock(side_effect=PermissionError(5, "Access is denied"))

        started = time.monotonic()
        with self.assertRaises(RModelTimeout):
            worker.request("slow", {"seconds": SLOW_SECONDS}, None)
        # Returned promptly rather than blocking on the worker's open streams.
        self.assertLess(time.monotonic() - started, TIMEOUT + 5)
        self.assertTrue(process.kill.called)

        # The worker could not be stopped, so the test stops it and its streams.
        real_kill()
        process.wait(timeout=10)
        for stream in (process.stdout, process.stderr):
            stream.close()

    def test_close_after_the_worker_exited_closes_its_stdin(self) -> None:
        worker = RWorker(WORKER_PYTHON, TIMEOUT)
        process = self.processes[-1]
        process.kill()
        process.wait(timeout=10)

        # The path a pool takes when it replaces a worker that died on its own.
        worker.close()

        self.assertTrue(process.stdin.closed)


if __name__ == "__main__":
    unittest.main(verbosity=2)
