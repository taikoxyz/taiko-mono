"""Regression tests for the alloc-only Etna genesis builder (stdlib only)."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PROTOCOL = Path(__file__).resolve().parents[3]
SCRIPT = PROTOCOL / "script/layer2/build_etna_genesis.py"


class EtnaGenesisBuilderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("etna_genesis", SCRIPT)
        cls.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.builder)

    def setUp(self):
        self.base = {
            "config": {"chainId": 167001, "extra": {"unchanged": True}},
            "timestamp": "0x0", "extraData": "0x001122", "gasLimit": "0x1c9c380",
            "alloc": {"ABCDEF0000000000000000000000000000000000": {"balance": "123"}},
        }

    def _system_account(self, code):
        return {"balance": "0x0", "nonce": "0x1", "code": code}

    def test_build_is_alloc_only_reproducible_and_zero_balance(self):
        self.base["stateRoot"] = "0x" + "aa" * 32
        before = json.loads(json.dumps(self.base))
        first = self.builder.build(self.base)
        second = self.builder.build(self.base)
        self.assertEqual(first, second)
        self.assertNotIn("stateRoot", first)
        self.assertEqual(self.base, before, "builder must not mutate input")
        self.assertEqual({k: v for k, v in first.items() if k != "alloc"},
                         {k: v for k, v in before.items() if k not in ("alloc", "stateRoot")})
        self.assertEqual(first["alloc"], {
            "0xabcdef0000000000000000000000000000000000": {"balance": "123"},
            "0x000f3df6d732807ef1319fb7b8bb8522d0beac02":
                self._system_account(self.builder.ROOTS_RUNTIME),
            "0x0000f90827f1c53a10cb7a02335b175320002935":
                self._system_account(self.builder.HISTORY_RUNTIME),
        })

    def test_replaces_prefixed_and_uppercase_target_allocs(self):
        roots = self.builder.ROOTS.removeprefix("0x")
        history = self.builder.HISTORY.removeprefix("0x")
        self.base["alloc"][roots.upper()] = {"balance": "99", "code": "0xffff"}
        self.base["alloc"]["0x" + history.upper()] = {"balance": "7", "nonce": "0x5"}
        alloc = self.builder.build(self.base)["alloc"]
        self.assertNotIn(roots.upper(), alloc)
        self.assertNotIn("0x" + history.upper(), alloc)
        self.assertEqual(alloc[self.builder.ROOTS], self._system_account(self.builder.ROOTS_RUNTIME))
        self.assertEqual(alloc[self.builder.HISTORY],
                         self._system_account(self.builder.HISTORY_RUNTIME))
        self.assertEqual(len(alloc), 3)

    def test_rejects_system_runtime_hash_drift(self):
        original = self.builder.ROOTS_RUNTIME
        try:
            self.builder.ROOTS_RUNTIME = "0x6000"
            with self.assertRaises(ValueError):
                self.builder.build(self.base)
        finally:
            self.builder.ROOTS_RUNTIME = original

    def test_cli_rejects_unknown_flags(self):
        self._assert_cli_rejected(json.dumps(self.base), "unrecognized arguments",
                                  ["--unknown", "x"])

    def test_cli_rejects_duplicate_literal_alloc_keys_without_output(self):
        key = "0xabcdef0000000000000000000000000000000000"
        raw_base = ('{"config":{"chainId":167001},"alloc":{'
                    + json.dumps(key) + ':{"balance":"123"},'
                    + json.dumps(key) + ':{"balance":"456"}}}')
        self._assert_cli_rejected(raw_base)

    def test_cli_rejects_normalized_alloc_aliases_without_output(self):
        self.base["alloc"]["0xabcdef0000000000000000000000000000000000"] = {"balance": "456"}
        self._assert_cli_rejected(json.dumps(self.base),
                                  "duplicate alloc address after normalization")

    def test_cli_valid_json_preserves_output_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, json.dumps(self.base))
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = (json.dumps(self.builder.build(self.base), sort_keys=True, indent=2)
                        + "\n").encode()
            self.assertEqual(output.read_bytes(), expected)

    def test_write_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "genesis.json"
            genesis = self.builder.build(self.base)
            self.builder.write(genesis, destination)
            first = destination.read_bytes()
            self.builder.write(genesis, destination)
            self.assertEqual(first, destination.read_bytes())
            self.assertTrue(first.endswith(b"\n"))

    def _assert_cli_rejected(self, raw_base, diagnostic="duplicate JSON key", extra_args=()):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, raw_base, extra_args)
            self.assertFalse(output.exists(), "rejected input must not create genesis output")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(diagnostic, result.stderr)

    def _run_cli(self, directory, raw_base, extra_args=()):
        base = Path(directory) / "base.json"
        output = Path(directory) / "genesis.json"
        base.write_text(raw_base)
        result = subprocess.run([sys.executable, str(SCRIPT), "--base", str(base),
                                 "--output", str(output), *extra_args],
                                text=True, capture_output=True, check=False)
        return result, output


if __name__ == "__main__":
    unittest.main()
