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
FIXTURE = Path(__file__).resolve().parent / "etna_genesis_fixture.py"


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class EtnaGenesisBuilderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = _module("etna_genesis", SCRIPT)
        cls.fixture = _module("etna_genesis_fixture", FIXTURE)

    def setUp(self):
        self.base = {
            "config": {"chainId": 167001, "extra": {"unchanged": True}},
            "timestamp": "0x0", "extraData": "0x001122", "gasLimit": "0x1c9c380",
            "alloc": {"ABCDEF0000000000000000000000000000000000": {"balance": "123"}},
        }
        self.addresses = dict(self.fixture.ADDRESSES)
        self.predeploys = self.fixture.predeploys()
        self.l1_signal_service = self.fixture.L1_SIGNAL_SERVICE
        self.config = self.fixture.config()
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.artifacts = Path(directory.name)
        self.fixture.write_artifacts(self.artifacts, self.fixture.artifacts())

    def _build(self, predeploys=None, config=None):
        return self.builder.build(self.base, self.predeploys if predeploys is None else predeploys,
                                  self.config if config is None else config,
                                  self.l1_signal_service, self.artifacts)

    def _system_account(self, code):
        return {"balance": "0x0", "nonce": "0x1", "code": code}

    def _set_code_byte(self, name, offset, value):
        account = self.predeploys[self.addresses[name]]
        code = bytearray.fromhex(account["code"].removeprefix("0x"))
        code[offset] = value
        account["code"] = "0x" + code.hex()

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
            with self.assertRaisesRegex(ValueError, "etnaTimestamp must be 0x0.*genesis_config.js"):
                self._build()
        for value in (0, "0", "", None):
            self.config["etnaTimestamp"] = value
            with self.assertRaisesRegex(ValueError, "0x-prefixed hex string"):
                self._build()

    def test_rejects_a_missing_or_other_l1_signal_service(self):
        self.config["remoteSignalService"] = "0x" + "00" * 20
        with self.assertRaisesRegex(ValueError, "remoteSignalService must be the L1"):
            self._build()
        self.config["remoteSignalService"] = "0x00000000000000000000000000000000000000bb"
        with self.assertRaisesRegex(ValueError, "remoteSignalService must be the L1"):
            self._build()
        self.config["remoteSignalService"] = self.l1_signal_service.upper().replace("0X", "0x")
        self._build()
        del self.config["remoteSignalService"]
        with self.assertRaises(ValueError):
            self._build()

    def test_projects_generator_accounts_to_genesis_fields(self):
        anchor = self.addresses["TaikoAnchor"]
        implementation = self.addresses["TaikoAnchorImpl"]
        self.predeploys[anchor] = {
            "contractName": "TaikoAnchor", "balance": "0x0", "code": "0x6001",
            "storage": {"0x01": "0xAB", "0x" + "cd" * 32: "0x" + "00" * 31 + "02",
                        self.fixture.IMPLEMENTATION_SLOT: implementation.upper().replace("0X", "0x")},
        }
        account = self._build()["alloc"][anchor]
        self.assertEqual(account, {
            "balance": "0x0", "code": "0x6001",
            "storage": {"0x" + "00" * 31 + "01": "0x" + "00" * 31 + "ab",
                        "0x" + "cd" * 32: "0x" + "00" * 31 + "02",
                        self.fixture.IMPLEMENTATION_SLOT: self.fixture.address_word(implementation)},
        })

    def test_rejects_predeploy_accounts_clients_cannot_parse(self):
        anchor = self.addresses["TaikoAnchor"]
        cases = [
            ({"balance": "0x0", "code": "0x60", "secretKey": "0x01"}, "unknown fields: secretKey"),
            ({"code": "0x60"}, "has no balance"),
            ({"balance": "0x0", "code": "0x60", "storage": {"0x1": "0x1", "0x01": "0x2"}},
             "duplicate storage slot"),
            ({"balance": "0x0", "code": "0x60", "storage": {"0x" + "00" * 33: "0x1"}},
             "at most 32 bytes"),
            ({"balance": "0x0", "code": "0x60", "storage": {"0x1": 1}}, "at most 32 bytes"),
        ]
        for account, diagnostic in cases:
            predeploys = dict(self.predeploys)
            predeploys[anchor] = account
            with self.assertRaisesRegex(ValueError, diagnostic):
                self._build(predeploys=predeploys)

    def test_rejects_predeploys_for_another_chain(self):
        self.config["chainId"] = 167
        with self.assertRaisesRegex(ValueError, "chainId differs"):
            self._build()

    def test_rejects_predeploys_without_the_root_path_contracts(self):
        for name in self.builder.REQUIRED_PREDEPLOYS:
            predeploys = dict(self.predeploys)
            del predeploys[self.addresses[name]]
            with self.assertRaisesRegex(ValueError, "no code at the configured " + name):
                self._build(predeploys=predeploys)
            predeploys[self.addresses[name]] = {"balance": "0x0", "code": "0x"}
            with self.assertRaisesRegex(ValueError, "no code at the configured " + name):
                self._build(predeploys=predeploys)
            config = json.loads(json.dumps(self.config))
            del config["contractAddresses"][name]
            with self.assertRaisesRegex(ValueError, "no " + name + " address"):
                self._build(config=config)

    def test_rejects_normalized_predeploy_aliases(self):
        anchor = self.addresses["TaikoAnchor"]
        self.predeploys[anchor.removeprefix("0x")] = self.predeploys[anchor]
        with self.assertRaisesRegex(ValueError, "duplicate predeploy address"):
            self._build()

    def test_rejects_an_ungated_anchor_in_the_bytecode_when_the_config_says_0(self):
        # A config file edited to 0x0 next to an alloc generated with the "never" default.
        never = self.fixture.word(2**64 - 1)
        self.predeploys = self.fixture.predeploys(etnaTimestamp=never)
        with self.assertRaisesRegex(ValueError, "TaikoAnchorImpl etnaTimestamp is " + never):
            self._build()

    def test_rejects_wrong_root_path_immutables(self):
        other = self.fixture.address_word("0x" + "cc" * 20)
        for immutable, name in (("checkpointStore", "TaikoAnchorImpl"),
                                ("_authorizedSyncer", "SignalServiceImpl"),
                                ("_remoteSignalService", "SignalServiceImpl")):
            self.predeploys = self.fixture.predeploys(**{immutable: other})
            with self.assertRaisesRegex(ValueError, name + " " + immutable + " is " + other):
                self._build()
        # Immutables the root path does not depend on, and library links, may hold anything.
        self.predeploys = self.fixture.predeploys(self=other, pauser=other)
        self._build()

    def test_rejects_an_immutable_with_two_values(self):
        # The stand-in Anchor reads etnaTimestamp at bytes 34 and 100; set only the second.
        self._set_code_byte("TaikoAnchorImpl", 131, 1)
        with self.assertRaisesRegex(ValueError, "etnaTimestamp differs between its offsets"):
            self._build()

    def test_rejects_code_that_is_not_the_compiled_runtime(self):
        for name, offset in (("TaikoAnchorImpl", 0), ("SignalServiceImpl", 33)):
            self.setUp()
            self._set_code_byte(name, offset, 0xFE)
            with self.assertRaisesRegex(ValueError, name + " is not the compiled runtime"):
                self._build()
        # A trailing byte, and the base SignalService instead of SignalServiceL2.
        self.setUp()
        account = self.predeploys[self.addresses["TaikoAnchorImpl"]]
        account["code"] += "00"
        with self.assertRaisesRegex(ValueError, "TaikoAnchorImpl is not the compiled runtime"):
            self._build()
        self.setUp()
        base_runtime = self.fixture.runtime(self.fixture.artifacts()["SignalService"], {
            "_authorizedSyncer": self.fixture.address_word(self.addresses["TaikoAnchor"]),
            "_remoteSignalService": self.fixture.address_word(self.l1_signal_service),
            "pauser": self.fixture.word(0),
        })
        self.predeploys[self.addresses["SignalServiceImpl"]]["code"] = base_runtime
        with self.assertRaisesRegex(ValueError, "SignalServiceImpl is not the compiled runtime"):
            self._build()

    def test_rejects_a_proxy_that_points_elsewhere(self):
        for proxy, implementation in (("TaikoAnchor", "TaikoAnchorImpl"),
                                      ("SignalService", "SignalServiceImpl")):
            self.setUp()
            storage = self.predeploys[self.addresses[proxy]]["storage"]
            storage[self.fixture.IMPLEMENTATION_SLOT] = self.fixture.address_word("0x" + "cc" * 20)
            with self.assertRaisesRegex(ValueError, "the " + proxy + " proxy does not point at "
                                        "the configured " + implementation):
                self._build()
            del storage[self.fixture.IMPLEMENTATION_SLOT]
            with self.assertRaisesRegex(ValueError, "the " + proxy + " proxy does not point"):
                self._build()

    def test_rejects_missing_or_incomplete_artifacts(self):
        contracts = self.fixture.artifacts()
        (self.artifacts / "Anchor.sol" / "Anchor.json").unlink()
        with self.assertRaisesRegex(ValueError, "Anchor.json; run `pnpm genesis:gen`"):
            self._build()
        anchor = json.loads(json.dumps(contracts["Anchor"]))
        del anchor["ast"]
        self.fixture.write_artifacts(self.artifacts, {"Anchor": anchor})
        with self.assertRaisesRegex(ValueError, "Anchor has no AST"):
            self._build()
        anchor = json.loads(json.dumps(contracts["Anchor"]))
        anchor["ast"]["nodes"][0]["nodes"][1]["mutability"] = "mutable"
        self.fixture.write_artifacts(self.artifacts, {"Anchor": anchor})
        with self.assertRaisesRegex(ValueError, "Anchor declares no immutable etnaTimestamp"):
            self._build()
        # An immutable the runtime never reads cannot carry the checked value. Its bytes are then
        # ordinary code, zero in the artifact.
        signal = json.loads(json.dumps(contracts["SignalServiceL2"]))
        del signal["deployedBytecode"]["immutableReferences"]["22"]
        self.fixture.write_artifacts(self.artifacts, {"Anchor": contracts["Anchor"],
                                                      "SignalServiceL2": signal})
        self.predeploys = self.fixture.predeploys(_remoteSignalService=self.fixture.word(0))
        with self.assertRaisesRegex(ValueError, "_remoteSignalService is never read"):
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
        self.config["etnaTimestamp"] = "0x0"
        self.predeploys = self.fixture.predeploys(etnaTimestamp=self.fixture.word(1))
        self._assert_cli_rejected(json.dumps(self.base), "TaikoAnchorImpl etnaTimestamp is")

    def test_fixture_script_builds_through_the_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "genesis.json"
            result = subprocess.run([sys.executable, str(FIXTURE), "--output", str(output)],
                                    text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            alloc = json.loads(output.read_text())["alloc"]
            self.assertEqual(len(alloc), 6, "four predeploys and two system contracts")

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
                                 "--predeploy-config", str(config),
                                 "--l1-signal-service", self.l1_signal_service,
                                 "--artifacts", str(self.artifacts),
                                 "--output", str(output)],
                                text=True, capture_output=True, check=False)
        return result, output


if __name__ == "__main__":
    unittest.main()
