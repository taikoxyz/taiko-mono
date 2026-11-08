"""Exercise the resource gate's deadline and the helper commands each profile measures."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
import checkpoint_import_resources as bench


class CompletedPhaseDeadline(unittest.TestCase):
    def run_reaped(self, elapsed):
        wait4 = os.wait4
        with tempfile.TemporaryDirectory() as directory:
            # Reap the real child on the first poll. Simulate the parent being descheduled
            # until the exact deadline or until just beyond it (both round to 600.000).
            with patch.object(bench.os, "wait4", lambda pid, _: wait4(pid, 0)), \
                 patch.object(bench.time, "monotonic", side_effect=[100.0, 100.0 + elapsed]):
                return bench.measure("verify", [sys.executable, "-c", "pass"],
                                     Path(directory), os.environ)

    def test_exact_deadline(self):
        self.assertEqual(self.run_reaped(600), "")

    def test_over_deadline_despite_rounding(self):
        with self.assertRaisesRegex(RuntimeError, "exceeded the predeclared 600 second limit"):
            self.run_reaped(600.0001)


class ProfileCommands(unittest.TestCase):
    def test_profile_uses_install_only_helpers(self):
        el_helper, stock_helper = "/opt/etna-el-import", "/opt/etna-comet-import"
        el_hash, state_root = "0x" + "11" * 32, "0x" + "22" * 32
        verified = dict(first_height=3, last_height=5, el_hash=el_hash, comet_hash="0x" + "33" * 32,
                        part_hash="44" * 32, part_total=1, state_root=state_root,
                        genesis_hash="0x" + "55" * 32, finalized_hash="0x" + "66" * 32, l1_calls=17,
                        frames=2, el_prefix_headers=1, terminal_q=4)
        receipts = {
            "el-install": dict(header_count=65_533, first_header=4, height=5, block_hash=el_hash,
                               state_root=state_root, finalized_hash=verified["finalized_hash"]),
            "stock-install": dict(first_height=3, last_height=5, block_id=dict(
                hash="0x" + "33" * 32, parts=dict(total=1, hash="0x" + "44" * 32))),
        }
        calls = []

        def measure(phase, args, directory, _env):
            calls.append([str(arg) for arg in args])
            if phase == "el-source":
                (directory / "source/db").mkdir(parents=True)
                for name in ("mdbx.dat", "database.version"):
                    (directory / "source/db" / name).write_bytes(b"stopped source")
            return json.dumps(receipts[phase]) if phase in receipts else ""

        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp).resolve()
            (directory / "verified.json").write_text(json.dumps(verified))
            (directory / "package.json").write_text(json.dumps(dict(validator_state="0x00")))
            for name in ("headers.json", "blocks.jsonl"):
                (directory / name).write_text("")
            with patch.object(bench, "measure", measure), \
                 patch.dict(os.environ, ETNA_EL_IMPORT_BIN=el_helper, ETNA_EL_BIN="/opt/alethia-reth"):
                self.assertEqual(bench.profile(directory, "lander-tests", stock_helper, 5, 4), 17)
        helpers = [argv for argv in calls if argv[0] in (el_helper, stock_helper)]
        for argv in helpers:
            self.assertNotIn("verify", argv)
            self.assertNotIn("export", argv)
        el, stock = ([argv for argv in helpers if argv[0] == helper] for helper in (el_helper, stock_helper))
        self.assertEqual(len(el), 1)
        self.assertEqual(el[0][1], "install")
        self.assertEqual(el[0][el[0].index("--source") + 1], str(directory / "source"))
        self.assertEqual(len(stock), 1)
        self.assertEqual(stock[0][1], "install")
        self.assertEqual(stock[0][stock[0].index("--stock-dir") + 1], str(directory / "stock"))
        self.assertEqual(stock[0][stock[0].index("--app-hash") + 1], el_hash)


if __name__ == "__main__":
    unittest.main()
