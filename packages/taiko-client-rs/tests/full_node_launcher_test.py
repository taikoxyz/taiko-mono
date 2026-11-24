"""The full-node launcher's pre-start guards (script/start_etna_full_node.py and
script/etna_comet_guard.py) with real child processes: the executable digest the deployment
manifest pins (CONS-3.1-1) and the pending-evidence store deleted before every start
(CONS-3.1-10, LIMIT-12-22)."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "script/start_etna_full_node.py"


def guard_module(name="etna_comet_guard_under_test"):
    spec = importlib.util.spec_from_file_location(name, ROOT / "script/etna_comet_guard.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FullNodeLauncherTests(unittest.TestCase):
    """One full-node home whose stub Comet records each start, and a manifest pinning it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name).resolve()
        self.home = self.base / "ready/comet"
        (self.home / "config").mkdir(parents=True)
        self.config("")
        self.starts = self.base / "starts"
        self.stub = self.base / "bin/cometbft"
        self.stub.parent.mkdir()
        # Each start records its argv and whether the evidence store existed when it began.
        self.stub.write_text(f'#!/bin/sh\n[ -e "{self.home}/data/evidence.db" ] && e=present || e=absent\n'
                             f'printf "%s %s\\n" "$e" "$*" >> "{self.starts}"\n')
        self.stub.chmod(0o700)
        self.manifest = self.base / "comet-manifest.json"
        self.pin(self.stub)
        self.env = dict(ETNA_COMET_HOME=str(self.home), ETNA_COMET_BIN=str(self.stub),
                        ETNA_COMET_MANIFEST=str(self.manifest), PATH=os.defpath)

    def tearDown(self):
        self.tmp.cleanup()

    def config(self, extra):
        (self.home / "config/config.toml").write_text('priv_validator_laddr = ""\n' + extra)

    def pin(self, executable, **override):
        guard = guard_module("etna_manifest_writer")
        manifest = dict(schema=3, engine="cometbft", release="v0.40.0",
                        source_commit="0880b4d378f347ab16e54ec677ff50d803f37d62",
                        platforms={guard.comet_platform(): dict(sha256=guard.sha256_file(executable))})
        manifest.update(override)
        self.manifest.write_text(json.dumps(manifest))

    def launch(self, **env):
        return subprocess.run([sys.executable, str(LAUNCHER)], env={**self.env, **env}, capture_output=True,
                              text=True, timeout=30)

    def started(self):
        return self.starts.read_text().splitlines() if self.starts.exists() else []

    def populate_evidence(self, data, marker):
        (data / "evidence.db/sub").mkdir(parents=True, exist_ok=True)
        (data / "evidence.db/000001.ldb").write_text(marker)
        (data / "evidence.db/sub/LOCK").write_text(marker)

    def test_only_the_pinned_executable_starts(self):
        """The executable whose digest the manifest pins for this platform starts; any other, an
        unsupported platform, a manifest for another release and a missing manifest are refused
        before Comet starts (CONS-3.1-1 vector 1.f)."""
        proc = self.launch()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self.started(), [f"absent start --home {self.home}"])
        guard = guard_module()
        platform = guard.comet_platform()
        for manifest, message in (
                (dict(platforms={platform: dict(sha256="00" * 32)}), f"not the {platform} digest"),
                (dict(platforms={}, unsupported_platforms={platform: "no official executable here"}),
                 "no official executable here (CONS-3.1-1)"),
                (dict(release="v0.38.0"), "is not a schema 3 manifest for CometBFT v0.40.0"),
                (dict(source_commit="00" * 20), "is not a schema 3 manifest for CometBFT v0.40.0"),
                (dict(schema=2), "is not a schema 3 manifest for CometBFT v0.40.0"),
                (dict(schema=1), "is not a schema 3 manifest for CometBFT v0.40.0")):
            with self.subTest(message=message):
                self.pin(self.stub, **manifest)
                proc = self.launch()
                self.assertEqual(proc.returncode, 1, proc.stderr)
                self.assertIn(message, proc.stderr)
                self.assertNotIn("Traceback", proc.stderr)
        proc = self.launch(ETNA_COMET_MANIFEST=str(self.base / "absent.json"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("CometBFT deployment manifest", proc.stderr)
        # A rebuilt executable no longer matches the pinned digest.
        self.pin(self.stub)
        self.stub.write_text(self.stub.read_text() + "# rebuilt\n")
        proc = self.launch()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("the deployment manifest pins (CONS-3.1-1)", proc.stderr)
        self.assertEqual(len(self.started()), 1, "no refused start ran Comet")

    def test_the_hashed_file_is_the_one_executed(self):
        """A bare ETNA_COMET_BIN is looked up on PATH once; the launcher execs the file it hashed,
        keeping the configured name as argv[0], so a later PATH entry cannot substitute another."""
        proc = self.launch(ETNA_COMET_BIN="cometbft", PATH=f"{self.stub.parent}:{os.defpath}")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self.started(), [f"absent start --home {self.home}"])
        proc = self.launch(ETNA_COMET_BIN="cometbft", PATH=os.defpath)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("CometBFT executable cometbft not found", proc.stderr)

    def test_the_sealed_copy_is_the_one_executed(self):
        """The executable is copied into a sealed memfd as it is hashed, and the copy is what
        runs: a write to the file in place, or another file renamed over its path, after the
        check reaches neither, and the copy refuses every write (CONS-3.1-1)."""
        guard = guard_module()
        sealed = guard.sealed_comet_executable(json.loads(self.manifest.read_text()), str(self.stub))
        try:
            self.stub.write_text(self.stub.read_text().replace("printf", "echo rewritten >> /dev/null; printf"))
            replacement = self.stub.with_name("replacement")
            replacement.write_text(f'#!/bin/sh\necho substituted >> "{self.starts}"\n')
            replacement.chmod(0o700)
            os.replace(replacement, self.stub)
            with self.assertRaises(PermissionError):
                os.write(sealed, b"#")
            self.assertEqual(fcntl.fcntl(sealed, fcntl.F_GET_SEALS) & guard.EXECUTABLE_SEALS, guard.EXECUTABLE_SEALS)
            subprocess.run(["cometbft", "start", "--home", str(self.home)], executable=guard.executable_path(sealed),
                           pass_fds=(sealed,), check=True, timeout=30)
        finally:
            os.close(sealed)
        self.assertEqual(self.started(), [f"absent start --home {self.home}"])
        # A file whose digest is not the pinned one is refused, and no copy of it is left open.
        before = len(os.listdir("/proc/self/fd"))
        with self.assertRaisesRegex(ValueError, "the deployment manifest pins"):
            guard.sealed_comet_executable(json.loads(self.manifest.read_text()), str(self.stub))
        self.assertEqual(len(os.listdir("/proc/self/fd")), before)

    def test_pending_evidence_store_is_deleted_before_every_start(self):
        """With no Comet on the home, every start deletes <db_dir>/evidence.db and nothing else:
        the WAL, block and state stores and their neighbours stay (CONS-3.1-10 vectors 10.f/10.g)."""
        data = self.home / "data"
        kept = {data / "blockstore.db/000001.ldb": "blocks", data / "state.db/000001.ldb": "state",
                data / "cs.wal/wal": "wal", data / "priv_validator_state.json": "dummy",
                data / "evidence.db.keep": "neighbour"}
        for path, text in kept.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        for marker in ("pending before the first start", "pending from the previous run"):
            self.populate_evidence(data, marker)
            proc = self.launch()
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertFalse(os.path.lexists(data / "evidence.db"))
            self.assertIn(f"etna_full_node_pending_evidence_removed: {data / 'evidence.db'}", proc.stdout)
        self.assertEqual(self.started(), [f"absent start --home {self.home}"] * 2)
        self.assertEqual({path: path.read_text() for path in kept}, kept)
        # Nothing to delete is not an error.
        proc = self.launch()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertNotIn("pending_evidence_removed", proc.stdout)

    def test_the_store_follows_db_dir_and_is_never_followed_through_a_link(self):
        """The store follows db_dir from config.toml, as stock rootify reads it, and an absolute
        one as is. Every CMT_* override is a candidate too, so one that disagrees with config.toml
        or the stock default is ambiguous; ambiguous settings, a backend that keeps the store
        elsewhere and a symlinked store are refused before Comet starts, leaving the link's
        target in place."""
        elsewhere = self.home / "elsewhere"
        self.config('db_dir = "elsewhere"\n')
        self.populate_evidence(elsewhere, "configured")
        proc = self.launch()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertFalse(os.path.lexists(elsewhere / "evidence.db"))
        absolute = self.base / "absolute"
        self.config(f'db_dir = "{absolute}"\n')
        self.populate_evidence(absolute, "overridden")
        proc = self.launch(CMT_DB_DIR=str(absolute))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertFalse(os.path.lexists(absolute / "evidence.db"))
        for extra, env, message in (
                ('db_dir = "elsewhere"\n', dict(CMT_DB_DIR="data"), "db_dir is ambiguous"),
                ("", dict(CMTDB_DIR=str(absolute)), "db_dir is ambiguous"),
                ('DB_DIR = "elsewhere"\ndb_dir = "data"\n', {}, "db_dir is ambiguous"),
                ('db_dir = 7\n', {}, "db_dir is ambiguous or invalid"),
                ('db_backend = "badgerdb"\n', {}, "db_backend must be one of"),
                ("", dict(CMT_DB_BACKEND="rocksdb"), "db_backend is ambiguous")):
            with self.subTest(extra=extra, env=env):
                self.config(extra)
                proc = self.launch(**env)
                self.assertEqual(proc.returncode, 1, proc.stderr)
                self.assertIn(message, proc.stderr)
        self.config("")
        target = self.base / "outside-evidence"
        target.mkdir()
        (target / "keep").write_text("outside")
        (self.home / "data").mkdir(exist_ok=True)
        (self.home / "data/evidence.db").symlink_to(target, target_is_directory=True)
        proc = self.launch()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("must not be a symlink", proc.stderr)
        self.assertEqual((target / "keep").read_text(), "outside")
        self.assertEqual(len(self.started()), 2, "no refused start ran Comet")

    def test_a_running_comet_keeps_its_evidence_store(self):
        """The store is deleted only under the writer lease: while another launcher's Comet holds
        it, the launcher refuses before touching the store."""
        data = self.home / "data"
        self.populate_evidence(data, "owned by the running Comet")
        lease = os.open(self.home.parent / ".comet.etna-owner.lock", os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = self.launch()
        finally:
            os.close(lease)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        self.assertEqual((data / "evidence.db/000001.ldb").read_text(), "owned by the running Comet")
        self.assertEqual(self.started(), [])

    def test_guard_reads_the_stock_default_and_refuses_unhashable_settings(self):
        guard = guard_module()
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(guard.evidence_store(self.home, {}), self.home / "data/evidence.db")
            self.assertEqual(guard.evidence_store(self.home, guard.config_values({"DB_Dir": "/srv/db"})),
                             Path("/srv/db/evidence.db"))
            for settings in ({"db_dir": [["a"]]}, {"db_dir": [{"a": 1}]}, {"db_dir": [""]}):
                with self.subTest(settings=settings), self.assertRaisesRegex(ValueError, "ambiguous or invalid"):
                    guard.evidence_store(self.home, settings)


if __name__ == "__main__":
    unittest.main()
