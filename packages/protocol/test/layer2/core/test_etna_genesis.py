"""Regression tests for the alloc-only Etna genesis builder (stdlib only)."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[3] / "script/layer2/build_etna_genesis.py"


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
        self.runtime = {"l1ChainId": "1", "l1Inbox": "0x" + "11" * 20, "runtime": "0x60016000"}

    def test_build_is_alloc_only_reproducible_and_zero_balance(self):
        before = json.loads(json.dumps(self.base))
        first = self.builder.build(self.base, self.runtime)
        second = self.builder.build(self.base, self.runtime)
        self.assertEqual(first, second)
        self.assertEqual(self.base, before, "builder must not mutate input")
        self.assertEqual({k: v for k, v in first.items() if k != "alloc"},
                         {k: v for k, v in before.items() if k != "alloc"})
        self.assertEqual(first["alloc"]["0xabcdef0000000000000000000000000000000000"], {"balance": "123"})
        vault = first["alloc"]["0x1670010000000000000000000000000000010001"]
        self.assertEqual(vault, {"balance": "0x0", "nonce": "0x1", "code": "0x60016000"})
        self.assertEqual(first["alloc"][self.builder.ROOTS]["code"], self.builder.ROOTS_RUNTIME)
        self.assertEqual(first["alloc"][self.builder.HISTORY]["code"], self.builder.HISTORY_RUNTIME)

    def test_replaces_prefixed_and_uppercase_target_allocs(self):
        target = "1670010000000000000000000000000000010001"
        self.base["alloc"][target.upper()] = {"balance": "99", "code": "0xffff"}
        result = self.builder.build(self.base, self.runtime)
        self.assertNotIn(target, result["alloc"])
        self.assertEqual(result["alloc"]["0x" + target]["balance"], "0x0")
        self.assertEqual(len(result["alloc"]), 4)

    def test_chain_id_changes_treasury_and_runtime_changes_alloc(self):
        changed = json.loads(json.dumps(self.base))
        changed["config"]["chainId"] = 167002
        result = self.builder.build(changed, self.runtime)
        self.assertIn("0x1670020000000000000000000000000000010001", result["alloc"])
        self.assertNotEqual(result, self.builder.build(self.base, self.runtime))
        altered = dict(self.runtime, runtime="0x60026000")
        self.assertNotEqual(self.builder.build(self.base, altered), self.builder.build(self.base, self.runtime))

    def test_rejects_ambiguous_allocs_invalid_identity_and_runtime(self):
        self.base["alloc"]["0xabcdef0000000000000000000000000000000000"] = {"balance": "456"}
        with self.assertRaises(ValueError):
            self.builder.build(self.base, self.runtime)
        self.base["alloc"] = {}
        for field, value in (("l1ChainId", "0"), ("l1Inbox", "0x" + "00" * 20),
                             ("runtime", "0x"), ("runtime", "0x123"), ("runtime", "0xzz")):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.builder.build(self.base, dict(self.runtime, **{field: value}))

    def test_rejects_system_runtime_hash_drift(self):
        original = self.builder.ROOTS_RUNTIME
        try:
            self.builder.ROOTS_RUNTIME = "0x6000"
            with self.assertRaises(ValueError):
                self.builder.build(self.base, self.runtime)
        finally:
            self.builder.ROOTS_RUNTIME = original

    def test_cli_rejects_duplicate_literal_alloc_keys_without_output(self):
        key = "0xabcdef0000000000000000000000000000000000"
        raw_base = ('{"config":{"chainId":167001},"alloc":{'
                    + json.dumps(key) + ':{"balance":"123"},'
                    + json.dumps(key) + ':{"balance":"456"}}}')
        self._assert_cli_rejected(raw_base, json.dumps(self.runtime))

    def test_cli_rejects_normalized_alloc_aliases_without_output(self):
        self.base["alloc"]["0xabcdef0000000000000000000000000000000000"] = {"balance": "456"}
        self._assert_cli_rejected(json.dumps(self.base), json.dumps(self.runtime),
                                  "duplicate alloc address after normalization")

    def test_cli_rejects_duplicate_runtime_metadata_keys_without_output(self):
        for key in ("l1ChainId", "l1Inbox", "runtime"):
            with self.subTest(key=key):
                # Repeating the same value is ambiguous too; neither occurrence may win.
                raw_runtime = ("{" + json.dumps(key) + ":" + json.dumps(self.runtime[key])
                               + "," + json.dumps(self.runtime)[1:])
                self._assert_cli_rejected(json.dumps(self.base), raw_runtime)

    def test_cli_valid_json_preserves_output_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, json.dumps(self.base), json.dumps(self.runtime))
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = (json.dumps(self.builder.build(self.base, self.runtime),
                                   sort_keys=True, indent=2) + "\n").encode()
            self.assertEqual(output.read_bytes(), expected)

    def _assert_cli_rejected(self, raw_base, raw_runtime, diagnostic="duplicate JSON key"):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, raw_base, raw_runtime)
            self.assertFalse(output.exists(), "ambiguous input must not create genesis output")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(diagnostic, result.stderr)

    def _run_cli(self, directory, raw_base, raw_runtime):
        base = Path(directory) / "base.json"
        runtime = Path(directory) / "runtime.json"
        output = Path(directory) / "genesis.json"
        base.write_text(raw_base)
        runtime.write_text(raw_runtime)
        result = subprocess.run([sys.executable, str(SCRIPT), "--base", str(base),
                                 "--runtime", str(runtime), "--output", str(output)],
                                text=True, capture_output=True, check=False)
        return result, output

    def test_write_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "genesis.json"
            genesis = self.builder.build(self.base, self.runtime)
            self.builder.write(genesis, destination)
            first = destination.read_bytes()
            self.builder.write(genesis, destination)
            self.assertEqual(first, destination.read_bytes())
            self.assertTrue(first.endswith(b"\n"))


if __name__ == "__main__":
    unittest.main()
