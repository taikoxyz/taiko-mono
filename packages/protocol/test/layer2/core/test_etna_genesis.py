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
        self.addresses = {
            "TaikoAnchor": "0x1670010000000000000000000000000000010001",
            "TaikoAnchorImpl": "0x0167001000000000000000000000000000010001",
            "SignalService": "0x1670010000000000000000000000000000000005",
            "SignalServiceImpl": "0x0167001000000000000000000000000000000005",
        }
        self.predeploys = {
            addr: {"balance": "0x0", "code": "0x60" + str(i)}
            for i, addr in enumerate(self.addresses.values())
        }
        self.config = {
            "chainId": 167001,
            "etnaTimestamp": "0x0",
            "remoteSignalService": "0x00000000000000000000000000000000000000aa",
            "contractAddresses": dict(self.addresses),
        }

    def _build(self):
        return self.builder.build(self.base, self.predeploys, self.config)

    def _system_account(self, code):
        return {"balance": "0x0", "nonce": "0x1", "code": code}

    def test_build_is_alloc_only_reproducible_and_zero_balance(self):
        self.base["stateRoot"] = "0x" + "aa" * 32
        before = json.loads(json.dumps([self.base, self.predeploys, self.config]))
        first = self._build()
        second = self._build()
        self.assertEqual(first, second)
        self.assertNotIn("stateRoot", first)
        self.assertEqual([self.base, self.predeploys, self.config], before,
                         "builder must not mutate input")
        before = before[0]
        self.assertEqual({k: v for k, v in first.items() if k != "alloc"},
                         {k: v for k, v in before.items() if k not in ("alloc", "stateRoot")})
        self.assertEqual(first["alloc"], {
            "0xabcdef0000000000000000000000000000000000": {"balance": "123"},
            **self.predeploys,
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
        alloc = self._build()["alloc"]
        self.assertNotIn(roots.upper(), alloc)
        self.assertNotIn("0x" + history.upper(), alloc)
        self.assertEqual(alloc[self.builder.ROOTS], self._system_account(self.builder.ROOTS_RUNTIME))
        self.assertEqual(alloc[self.builder.HISTORY],
                         self._system_account(self.builder.HISTORY_RUNTIME))
        self.assertEqual(len(alloc), 7)

    def test_predeploys_replace_base_accounts_at_the_same_address(self):
        anchor = self.addresses["TaikoAnchor"]
        self.base["alloc"][anchor.removeprefix("0x")] = {
            "balance": "0x1", "code": "0xdead", "storage": {"0x00": "0x01"},
        }
        alloc = self._build()["alloc"]
        self.assertEqual(alloc[anchor], self.predeploys[anchor])

    def test_rejects_an_anchor_without_the_etna_gate(self):
        for value in ("0xffffffffffffffff", "0x1"):
            self.config["etnaTimestamp"] = value
            with self.assertRaisesRegex(ValueError, "etnaTimestamp must be 0x0"):
                self._build()
        for value in (0, "0", "", None):
            self.config["etnaTimestamp"] = value
            with self.assertRaisesRegex(ValueError, "0x-prefixed hex string"):
                self._build()

    def test_rejects_a_missing_l1_signal_service(self):
        self.config["remoteSignalService"] = "0x" + "00" * 20
        with self.assertRaisesRegex(ValueError, "remoteSignalService must name"):
            self._build()
        del self.config["remoteSignalService"]
        with self.assertRaises(ValueError):
            self._build()

    def test_rejects_predeploys_for_another_chain(self):
        self.config["chainId"] = 167
        with self.assertRaisesRegex(ValueError, "chainId differs"):
            self._build()

    def test_rejects_predeploys_without_the_root_path_contracts(self):
        for name in self.builder.REQUIRED_PREDEPLOYS:
            predeploys = dict(self.predeploys)
            del predeploys[self.addresses[name]]
            with self.assertRaisesRegex(ValueError, "no code at the configured " + name):
                self.builder.build(self.base, predeploys, self.config)
            predeploys[self.addresses[name]] = {"balance": "0x0", "code": "0x"}
            with self.assertRaisesRegex(ValueError, "no code at the configured " + name):
                self.builder.build(self.base, predeploys, self.config)
            config = json.loads(json.dumps(self.config))
            del config["contractAddresses"][name]
            with self.assertRaisesRegex(ValueError, "no " + name + " address"):
                self.builder.build(self.base, self.predeploys, config)

    def test_rejects_normalized_predeploy_aliases(self):
        anchor = self.addresses["TaikoAnchor"]
        self.predeploys[anchor.removeprefix("0x")] = self.predeploys[anchor]
        with self.assertRaisesRegex(ValueError, "duplicate predeploy address"):
            self._build()

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
            expected = (json.dumps(self._build(), sort_keys=True, indent=2) + "\n").encode()
            self.assertEqual(output.read_bytes(), expected)

    def test_cli_rejects_an_ungated_anchor_without_output(self):
        self.config["etnaTimestamp"] = "0xffffffffffffffff"
        self._assert_cli_rejected(json.dumps(self.base), "etnaTimestamp must be 0x0")

    def _assert_cli_rejected(self, raw_base, diagnostic="duplicate JSON key"):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, raw_base)
            self.assertFalse(output.exists(), "rejected input must not create genesis output")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(diagnostic, result.stderr)

    def _run_cli(self, directory, raw_base):
        base = Path(directory) / "base.json"
        predeploys = Path(directory) / "genesis_alloc.json"
        config = Path(directory) / "genesis_config.json"
        output = Path(directory) / "genesis.json"
        base.write_text(raw_base)
        predeploys.write_text(json.dumps(self.predeploys))
        config.write_text(json.dumps(self.config))
        result = subprocess.run([sys.executable, str(SCRIPT), "--base", str(base),
                                 "--predeploys", str(predeploys),
                                 "--predeploy-config", str(config), "--output", str(output)],
                                text=True, capture_output=True, check=False)
        return result, output


if __name__ == "__main__":
    unittest.main()
