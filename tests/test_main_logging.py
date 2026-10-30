#!/usr/bin/env python3
"""Logging set-up tests for api/main.py.

The API is started two ways: `api/run_api.py`, which calls main(), and
`uvicorn api.main:app`, which only runs the lifespan. Both must log the
application's own ``eqalb.*`` messages, once each, at EQALB_LOG_LEVEL.

No R is started. The worker pool is replaced by a stand-in that logs what a real
worker logs when it becomes ready, and uvicorn.run is never called.

    api/.venv/Scripts/python.exe tests/test_main_logging.py   # Windows
    api/.venv/bin/python tests/test_main_logging.py           # elsewhere

The script exits non-zero if any check fails.
"""

from __future__ import annotations

import asyncio
import io
import logging
import os
import sys
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

API_DIR = Path(__file__).resolve().parent.parent / "api"
sys.path.insert(0, str(API_DIR))

import main  # noqa: E402  (needs the path above)
import r_client  # noqa: E402

WARMUP = main._warmup  # the real one, wrapped by each test

WORKER_READY = "INFO eqalb.r_model: R worker ready (pid fake, 0 endpoints)"
POOL_READY = "INFO eqalb.api: Model workers ready"
LEVEL_WARNING = "WARNING eqalb.api: EQALB_LOG_LEVEL='LOUD' is not a log level; using INFO."


class FakePool:
    """Stands in for RModelPool; logs what a worker logs once it is ready."""

    def __init__(self) -> None:
        # Whether logging was configured when the pool was created, i.e. before
        # any worker could log its start-up.
        eqalb = logging.getLogger("eqalb")
        self.logging_ready_at_start = any(
            isinstance(handler, main._EqalbLogHandler) for handler in eqalb.handlers
        )
        self.closed = False

    def warmup(self) -> None:
        logging.getLogger("eqalb.r_model").info("R worker ready (pid fake, 0 endpoints)")

    def status(self) -> dict:
        return {"configured_workers": 1, "ready_workers": 1}

    def close(self) -> None:
        self.closed = True


class RecordingHandler(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


class LoggingSetupTests(unittest.TestCase):
    def setUp(self) -> None:
        root = logging.getLogger()
        eqalb = logging.getLogger("eqalb")
        saved_root = (list(root.handlers), root.level)
        saved_eqalb = (list(eqalb.handlers), eqalb.level, eqalb.propagate)
        had_pool = hasattr(main.app.state, "pool")

        def restore() -> None:
            for logger, (handlers, level) in ((root, saved_root), (eqalb, saved_eqalb[:2])):
                for handler in logger.handlers:
                    if handler not in handlers:
                        handler.close()
                logger.handlers[:] = handlers
                logger.setLevel(level)
            eqalb.propagate = saved_eqalb[2]
            if not had_pool:
                for name in ("pool", "model_error"):
                    if hasattr(main.app.state, name):
                        delattr(main.app.state, name)

        self.addCleanup(restore)
        # Each test starts as a fresh process would: nothing configured.
        for logger in (root, eqalb):
            for handler in list(logger.handlers):
                logger.removeHandler(handler)
        root.setLevel(logging.WARNING)
        eqalb.setLevel(logging.NOTSET)
        eqalb.propagate = True

        environ = mock.patch.dict(os.environ)
        environ.start()
        self.addCleanup(environ.stop)
        os.environ.pop("EQALB_LOG_LEVEL", None)

        # Handlers created during a test write here instead of the real stderr.
        self.stderr = io.StringIO()
        for patcher in (
            mock.patch.object(sys, "stderr", self.stderr),
            mock.patch.object(sys, "stdout", io.StringIO()),
            mock.patch.object(main, "create_pool", side_effect=self.create_pool),
            # A guard: nothing here may look for, let alone start, R.
            mock.patch.object(r_client, "find_rscript", side_effect=AssertionError("R requested")),
            mock.patch("uvicorn.run"),
            mock.patch.object(main, "_warmup", side_effect=self.warmup),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)
        self.pools: list[FakePool] = []
        self.warmed_up = threading.Event()

    def create_pool(self) -> FakePool:
        pool = FakePool()
        self.pools.append(pool)
        return pool

    def warmup(self, pool: FakePool) -> None:
        # The real _warmup, plus a signal that it has finished logging.
        try:
            WARMUP(pool)
        finally:
            self.warmed_up.set()

    # --- helpers ------------------------------------------------------------

    def run_lifespan(self) -> None:
        """Start and stop the app as uvicorn does, once the warm-up has finished."""

        async def serve() -> None:
            async with main.lifespan(main.app):
                deadline = time.monotonic() + 5
                while not self.warmed_up.is_set():
                    if time.monotonic() > deadline:
                        self.fail("the warm-up did not finish")
                    await asyncio.sleep(0.01)

        self.warmed_up.clear()
        asyncio.run(serve())

    def output(self) -> str:
        return self.stderr.getvalue()

    def eqalb_handlers(self) -> list[logging.Handler]:
        return [
            handler
            for handler in logging.getLogger("eqalb").handlers
            if isinstance(handler, main._EqalbLogHandler)
        ]

    # --- launch paths -------------------------------------------------------

    def test_uvicorn_launch_logs_worker_start_once(self) -> None:
        self.run_lifespan()

        self.assertTrue(self.pools[0].logging_ready_at_start)
        self.assertEqual(self.output().count(WORKER_READY), 1)
        self.assertEqual(self.output().count(POOL_READY), 1)
        self.assertTrue(self.pools[0].closed)

    def test_run_api_launch_logs_each_record_once(self) -> None:
        main.main()
        self.run_lifespan()  # what uvicorn.run would do next

        self.assertTrue(self.pools[0].logging_ready_at_start)
        self.assertEqual(self.output().count(WORKER_READY), 1)
        self.assertEqual(self.output().count(POOL_READY), 1)
        # Third-party loggers still log through the root, as before.
        logging.getLogger("thirdparty.lib").info("library message")
        self.assertEqual(self.output().count("INFO thirdparty.lib: library message"), 1)
        self.assertEqual(logging.getLogger().level, logging.INFO)

    # --- repeated configuration --------------------------------------------

    def test_repeated_configuration_adds_no_handler(self) -> None:
        main.configure_logging()
        main.configure_logging()
        self.run_lifespan()
        self.run_lifespan()

        self.assertEqual(len(self.eqalb_handlers()), 1)
        logging.getLogger("eqalb.api").info("one line")
        self.assertEqual(self.output().count("INFO eqalb.api: one line"), 1)

    # --- level ----------------------------------------------------------------

    def test_log_level_is_respected(self) -> None:
        os.environ["EQALB_LOG_LEVEL"] = "warning"
        main.main()
        self.run_lifespan()

        self.assertNotIn(WORKER_READY, self.output())
        self.assertNotIn(POOL_READY, self.output())
        logging.getLogger("eqalb.r_model").warning("slot timed out")
        self.assertEqual(self.output().count("WARNING eqalb.r_model: slot timed out"), 1)
        # The root follows the same level for third-party loggers, as before.
        self.assertEqual(logging.getLogger().level, logging.WARNING)
        logging.getLogger("thirdparty.lib").info("quiet")
        self.assertNotIn("quiet", self.output())

    def test_invalid_level_falls_back_to_info_with_one_warning(self) -> None:
        os.environ["EQALB_LOG_LEVEL"] = "LOUD"
        main.main()
        self.run_lifespan()
        main.configure_logging()

        self.assertEqual(self.output().count(LEVEL_WARNING), 1)
        self.assertEqual(self.output().count(WORKER_READY), 1)
        self.assertEqual(logging.getLogger("eqalb").level, logging.INFO)
        self.assertEqual(logging.getLogger().level, logging.INFO)

    def test_invalid_level_under_uvicorn_launch(self) -> None:
        os.environ["EQALB_LOG_LEVEL"] = "LOUD"
        self.run_lifespan()
        self.run_lifespan()

        self.assertEqual(self.output().count(LEVEL_WARNING), 1)
        self.assertEqual(self.output().count(WORKER_READY), 2)  # one per start

    # --- root logging -----------------------------------------------------------

    def test_lifespan_leaves_root_logging_untouched(self) -> None:
        root = logging.getLogger()
        existing = RecordingHandler()
        root.addHandler(existing)
        root.setLevel(logging.ERROR)

        self.run_lifespan()

        self.assertEqual(root.handlers, [existing])
        self.assertEqual(root.level, logging.ERROR)
        # eqalb records are written once by their own handler, not again here.
        self.assertEqual(
            [r for r in existing.records if r.name.startswith("eqalb")], []
        )
        self.assertEqual(self.output().count(WORKER_READY), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
