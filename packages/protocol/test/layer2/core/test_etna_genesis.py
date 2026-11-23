"""Regression tests for the alloc-only Etna genesis builder (stdlib only)."""
import importlib.util
import json
import re
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
        self.l1_inbox = self.fixture.L1_INBOX
        self.l1_taiko_token = self.fixture.L1_TAIKO_TOKEN
        self.config = self.fixture.config()
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.artifacts = Path(directory.name)
        self.fixture.write_artifacts(self.artifacts, self.fixture.artifacts())

    def _build(self, predeploys=None, config=None):
        return self.builder.build(self.base, self.predeploys if predeploys is None else predeploys,
                                  self.config if config is None else config,
                                  self.l1_signal_service, l1_inbox=self.l1_inbox,
                                  l1_taiko_token=self.l1_taiko_token, artifacts=self.artifacts)

    def _assert_refused(self, diagnostic):
        """Require the build to fail with a one-line diagnostic matching `diagnostic`, both when
        called and through the CLI, which then leaves no output file."""
        with self.assertRaisesRegex(ValueError, diagnostic) as caught:
            self._build()
        self.assertNotIn("\n", str(caught.exception))
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, json.dumps(self.base))
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists(), "a refused genesis must leave no output file")
            self.assertTrue(result.stderr.startswith("build_etna_genesis.py: error: "),
                            result.stderr)
            self.assertEqual(result.stderr.count("\n"), 1, result.stderr)
            self.assertRegex(result.stderr, diagnostic)

    def _etna(self, **values):
        """Set fields of the configuration's `etna` block."""
        self.config["etna"].update(values)

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
        self.assertEqual(len(alloc), 12)

    def test_predeploys_replace_base_accounts_at_the_same_address(self):
        anchor = self.addresses["TaikoAnchor"]
        self.base["alloc"][anchor.removeprefix("0x")] = {
            "balance": "0x1", "code": "0xdead", "storage": {"0x00": "0x01"},
        }
        alloc = self._build()["alloc"]
        self.assertEqual(alloc[anchor], self.predeploys[anchor])

    def test_rejects_a_signal_service_without_beacon_roots(self):
        # Vector 5.v: without `usesBeaconRoots` the checkpoint store never closes, though every
        # block after genesis is an Etna block (5.aa).
        self.config["usesBeaconRoots"] = False
        with self.assertRaisesRegex(ValueError, "usesBeaconRoots must be true on a new Etna "
                                    "network, .*genesis_config.js"):
            self._build()
        # Only a JSON boolean: not a number, a string or the former fork-time field.
        for value in (1, 0, "true", "0x1", "", None):
            self.config["usesBeaconRoots"] = value
            with self.assertRaisesRegex(ValueError, "usesBeaconRoots must be a JSON boolean"):
                self._build()
        del self.config["usesBeaconRoots"]
        self.config["beaconRootsFrom"] = "0x1"
        with self.assertRaisesRegex(ValueError, "usesBeaconRoots must be a JSON boolean"):
            self._build()

    def test_accepts_any_base_genesis_timestamp(self):
        # Vector 5.ab: no L2 contract holds the fork time, so the genesis timestamp plays no part
        # and passes through unchanged.
        for value in ("0x0", "0x64", 100):
            self.base["timestamp"] = value
            self.assertEqual(self._build()["timestamp"], value)
        del self.base["timestamp"]
        self.assertNotIn("timestamp", self._build())

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
        code = self.predeploys[anchor]["code"]
        owner = self.fixture.OWNER
        self.predeploys[anchor] = {
            "contractName": "TaikoAnchor", "balance": "0x0", "code": code.upper().replace("0X", "0x"),
            "storage": {"0x0": "0x1", "0x33": owner.upper().replace("0X", "0x"), "0xC9": "0x101",
                        "0x100": "0x0",
                        self.fixture.IMPLEMENTATION_SLOT: implementation.upper().replace("0X", "0x")},
        }
        account = self._build()["alloc"][anchor]
        word = self.fixture.word
        self.assertEqual(account, {
            "balance": "0x0", "code": code,
            "storage": {word(0): word(1), word(51): self.fixture.address_word(owner),
                        word(201): word(0x101), word(256): word(0),
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
            # Code clients cannot parse: an odd digit count, whitespace, no prefix, not a string.
            ({"balance": "0x0", "code": "0x6"}, "code must be 0x-prefixed hex bytes"),
            ({"balance": "0x0", "code": "0x60 00"}, "code must be 0x-prefixed hex bytes"),
            ({"balance": "0x0", "code": "6000"}, "code must be 0x-prefixed hex bytes"),
            ({"balance": "0x0", "code": 96}, "code must be 0x-prefixed hex bytes"),
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

    def test_rejects_an_open_checkpoint_store_in_the_bytecode_when_the_config_says_true(self):
        # A config file edited to true next to an alloc generated with the default `false`.
        zero = self.fixture.word(0)
        self.predeploys = self.fixture.predeploys(usesBeaconRoots=zero)
        with self.assertRaisesRegex(ValueError, "SignalServiceImpl usesBeaconRoots is " + zero):
            self._build()
        # A `bool` immutable holds exactly 0 or 1.
        two = self.fixture.word(2)
        self.predeploys = self.fixture.predeploys(usesBeaconRoots=two)
        with self.assertRaisesRegex(ValueError, "SignalServiceImpl usesBeaconRoots is " + two):
            self._build()

    def test_rejects_wrong_root_path_immutables(self):
        other = self.fixture.address_word("0x" + "cc" * 20)
        # Every immutable of both implementations is pinned: a zero `__self` makes the genesis
        # proxy unupgradeable and a non-zero `pauser` adds a pause authority over bridging.
        for immutable, name in (("__self", "TaikoAnchorImpl"),
                                ("__resolver", "TaikoAnchorImpl"),
                                ("checkpointStore", "TaikoAnchorImpl"),
                                ("l1ChainId", "TaikoAnchorImpl"),
                                ("_authorizedSyncer", "SignalServiceImpl"),
                                ("_remoteSignalService", "SignalServiceImpl"),
                                ("pauser", "SignalServiceImpl"),
                                ("usesBeaconRoots", "SignalServiceImpl")):
            self.predeploys = self.fixture.predeploys(**{immutable: other})
            with self.assertRaisesRegex(ValueError, name + " " + immutable + " is " + other
                                        + ".*rerun `pnpm genesis:gen`"):
                self._build()
        # Each implementation's `__self` is its own address, and only the SignalService has a
        # resolver.
        anchor_self = self.fixture.address_word(self.addresses["TaikoAnchorImpl"])
        self.predeploys = self.fixture.predeploys(__self=anchor_self, __resolver=self.fixture.word(0))
        with self.assertRaisesRegex(ValueError, "SignalServiceImpl __self is " + anchor_self):
            self._build()

    def test_rejects_an_immutable_the_builder_does_not_check(self):
        for contract in ("Anchor", "EtnaStaking", "BridgedTaikoToken"):
            self.setUp()
            artifact = self.fixture.artifacts()[contract]
            artifact["deployedBytecode"]["immutableReferences"]["99"] = []
            self.fixture.write_artifacts(self.artifacts, {contract: artifact})
            with self.assertRaisesRegex(ValueError, contract + " has immutables the builder does "
                                        r"not check \(AST ids 99\)"):
                self._build()

    def test_rejects_proxy_storage_the_generator_does_not_write(self):
        word = self.fixture.word
        cases = (
            # A seeded received signal or checkpoint in SignalService's mappings (slots 253, 254).
            ("SignalService", "0x" + "ab" * 32, word(1)),
            # Paused (`__paused` = 2), uninitialized, or another owner.
            ("SignalService", word(201), word(0x0201)),
            # The generator writes `__reentry` 1 into these proxies, unlike the Etna ones.
            ("TaikoAnchor", word(201), word(0x0100)),
            ("TaikoAnchor", word(0), word(0)),
            ("TaikoAnchor", word(51), self.fixture.address_word("0x" + "cc" * 20)),
            # A non-zero `_blockState`.
            ("TaikoAnchor", word(256), word(7)),
        )
        for proxy, slot, value in cases:
            self.setUp()
            self.predeploys[self.addresses[proxy]]["storage"][slot] = value
            with self.assertRaisesRegex(ValueError, "the " + proxy + " proxy's storage slot "
                                        + slot + " is " + value):
                self._build()
        self.setUp()
        del self.predeploys[self.addresses["SignalService"]]["storage"][word(51)]
        with self.assertRaisesRegex(ValueError, "SignalService proxy's storage slot " + word(51)):
            self._build()

    def test_rejects_reserved_and_confused_addresses(self):
        # A root-path contract at a precompile would not run its code: at 0x02 SHA-256 answers
        # every call with 32 bytes.
        for name in self.builder.REQUIRED_PREDEPLOYS:
            for reserved in ("0x" + "00" * 19 + "02", "0x" + "00" * 18 + "ffff",
                             self.builder.ROOTS, self.builder.HISTORY):
                config = json.loads(json.dumps(self.config))
                config["contractAddresses"][name] = reserved
                with self.assertRaisesRegex(ValueError, name + " " + reserved.lower()
                                            + " is a precompile or system contract"):
                    self._build(config=config)
        # The L1 SignalService flag: not reserved, and not an L2 predeploy.
        for l1, diagnostic in (("0x" + "00" * 19 + "02", "is a precompile"),
                               (self.addresses["SignalService"], "is an L2 predeploy address")):
            self.l1_signal_service = l1
            self.config["remoteSignalService"] = l1
            with self.assertRaisesRegex(ValueError, "--l1-signal-service .*" + diagnostic):
                self._build()
        # The same for the L1 Inbox and L1 TAIKO flags.
        for flag, attribute, field in (("--l1-inbox", "l1_inbox", "inbox"),
                                       ("--l1-taiko-token", "l1_taiko_token", "l1TaikoToken")):
            for l1, diagnostic in (("0x" + "00" * 19 + "02", "is a precompile"),
                                   (self.builder.ROOTS, "is a precompile or system contract"),
                                   (self.addresses["EtnaStaking"], "is an L2 predeploy address")):
                self.setUp()
                setattr(self, attribute, l1)
                self._etna(**{field: l1})
                self._assert_refused(flag + " " + l1.lower() + " " + diagnostic)

    def test_rejects_malformed_chain_ids_and_owner(self):
        cases = (
            ("chainId", True, "chainId must be a positive integer"),
            ("l1ChainId", True, "l1ChainId must be a positive integer"),
            ("l1ChainId", None, "l1ChainId must be a positive integer"),
            ("l1ChainId", 0, "l1ChainId must be a positive integer"),
            ("l1ChainId", 167001, "l1ChainId equals the L2 chain id"),
            ("contractOwner", None, "contractOwner must be a non-zero address"),
            ("contractOwner", "0x" + "00" * 20, "contractOwner must be a non-zero address"),
        )
        for field, value, diagnostic in cases:
            config = json.loads(json.dumps(self.config))
            config[field] = value
            with self.assertRaisesRegex(ValueError, diagnostic):
                self._build(config=config)
        self.base["config"]["chainId"] = True
        with self.assertRaisesRegex(ValueError, "base genesis: config.chainId must be"):
            self._build()
        self.base["config"]["chainId"] = self.fixture.CHAIN_ID
        config = json.loads(json.dumps(self.config))
        del config["contractAddresses"]["SharedResolver"]
        with self.assertRaisesRegex(ValueError, "no SharedResolver address"):
            self._build(config=config)

    def test_rejects_an_immutable_with_two_values(self):
        # The stand-in SignalService reads usesBeaconRoots at bytes 34 and 133; change only the
        # second.
        self._set_code_byte("SignalServiceImpl", 140, 1)
        with self.assertRaisesRegex(ValueError, "usesBeaconRoots differs between its offsets"):
            self._build()

    def test_rejects_proxy_code_that_is_not_the_compiled_proxy(self):
        # Calls land at the proxy: a SignalService runtime there with an open checkpoint store,
        # still pointing at a checked implementation, would accept forged checkpoints.
        open_store = self.fixture.predeploys(usesBeaconRoots=self.fixture.word(0))
        self.predeploys[self.addresses["SignalService"]]["code"] = (
            open_store[self.addresses["SignalServiceImpl"]]["code"])
        with self.assertRaisesRegex(ValueError, "SignalService is not the compiled ERC1967Proxy"):
            self._build()
        self.setUp()
        self.predeploys[self.addresses["TaikoAnchor"]]["code"] = (
            self.predeploys[self.addresses["TaikoAnchorImpl"]]["code"])
        with self.assertRaisesRegex(ValueError, "TaikoAnchor is not the compiled ERC1967Proxy"):
            self._build()
        self.setUp()
        self.predeploys[self.addresses["SignalService"]]["code"] = "0x00"
        with self.assertRaisesRegex(ValueError, "SignalService is not the compiled ERC1967Proxy"):
            self._build()
        self.setUp()
        self._set_code_byte("SignalService", 3, 0xFE)
        with self.assertRaisesRegex(ValueError, "SignalService is not the compiled ERC1967Proxy"):
            self._build()
        # The block-start call and every stake transfer land at the two Etna proxies.
        for proxy in ("EtnaStaking", "BridgedTaikoToken"):
            self.setUp()
            self.predeploys[self.addresses[proxy]]["code"] = (
                self.predeploys[self.addresses[proxy + "Impl"]]["code"])
            self._assert_refused(proxy + " is not the compiled ERC1967Proxy")

    def test_rejects_root_path_artifacts_that_link_a_library(self):
        # A linked library would be a call target the immutable check does not cover.
        signal = self.fixture.artifacts()["SignalService"]
        signal["deployedBytecode"]["linkReferences"] = {
            "contracts/Lib.sol": {"Lib": [{"start": 232, "length": 20}]}}
        self.fixture.write_artifacts(self.artifacts, {"SignalService": signal})
        with self.assertRaisesRegex(ValueError, "SignalService links a library"):
            self._build()

    def test_rejects_an_immutable_that_is_not_32_bytes(self):
        signal = self.fixture.artifacts()["SignalService"]
        # A bool read as its low byte only, so the code still matches the artifact.
        signal["deployedBytecode"]["immutableReferences"]["24"][0]["start"] += 31
        signal["deployedBytecode"]["immutableReferences"]["24"][0]["length"] = 1
        self.fixture.write_artifacts(self.artifacts, {"SignalService": signal})
        with self.assertRaisesRegex(ValueError, "usesBeaconRoots is not a 32-byte immutable"):
            self._build()

    def test_rejects_code_that_is_not_the_compiled_runtime(self):
        for name, contract, offset in (("TaikoAnchorImpl", "Anchor", 0),
                                       ("SignalServiceImpl", "SignalService", 33),
                                       ("EtnaStakingImpl", "EtnaStaking", 33),
                                       ("BridgedTaikoTokenImpl", "BridgedTaikoToken", 0)):
            self.setUp()
            self._set_code_byte(name, offset, 0xFE)
            # The message names the artifacts directory and how to point at the right one.
            with self.assertRaisesRegex(ValueError, name + " is not the compiled " + contract
                                        + " runtime in " + re.escape(str(self.artifacts))
                                        + ".*--artifacts"):
                self._build()
        # A trailing byte, and the Anchor's runtime in place of the SignalService's.
        self.setUp()
        account = self.predeploys[self.addresses["TaikoAnchorImpl"]]
        account["code"] += "00"
        with self.assertRaisesRegex(ValueError, "TaikoAnchorImpl is not the compiled Anchor"):
            self._build()
        self.setUp()
        self.predeploys[self.addresses["SignalServiceImpl"]]["code"] = (
            self.predeploys[self.addresses["TaikoAnchorImpl"]]["code"])
        with self.assertRaisesRegex(ValueError,
                                    "SignalServiceImpl is not the compiled SignalService"):
            self._build()
        self.setUp()
        self.predeploys[self.addresses["EtnaStakingImpl"]]["code"] = (
            self.predeploys[self.addresses["BridgedTaikoTokenImpl"]]["code"])
        self._assert_refused("EtnaStakingImpl is not the compiled EtnaStaking")

    def test_rejects_a_proxy_that_points_elsewhere(self):
        for proxy, implementation in (("TaikoAnchor", "TaikoAnchorImpl"),
                                      ("SignalService", "SignalServiceImpl"),
                                      ("EtnaStaking", "EtnaStakingImpl"),
                                      ("BridgedTaikoToken", "BridgedTaikoTokenImpl")):
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
        with self.assertRaisesRegex(ValueError, "Anchor declares no immutable l1ChainId"):
            self._build()
        # An immutable the runtime never reads cannot carry the checked value. Its bytes are then
        # ordinary code, zero in the artifact.
        signal = json.loads(json.dumps(contracts["SignalService"]))
        del signal["deployedBytecode"]["immutableReferences"]["22"]
        self.fixture.write_artifacts(self.artifacts, {"Anchor": contracts["Anchor"],
                                                      "SignalService": signal})
        self.predeploys = self.fixture.predeploys(_remoteSignalService=self.fixture.word(0))
        with self.assertRaisesRegex(ValueError, "_remoteSignalService has no offsets"):
            self._build()

    def test_keccak256_matches_known_digests(self):
        # Digests from `cast keccak`, around the 136-byte rate and over two blocks.
        keccak = self.builder.keccak256
        for data, digest in (
            (b"", "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"),
            (b"abc", "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"),
            (b"\xaa" * 135, "aba4a58b3b2fcbcdc90624cc76fb6acc522abffc59c25642a5aaaafd00469e8b"),
            (b"\xab" * 136, "302db73a4c8cc8ecc9004fec3a6525d9d6a2dd4b098b1bf62d1b897acff18c9d"),
            (b"\xcd" * 137, "a36a60e27418e5c6d9be6d4ee9fc9c313465df309abb53028081eaba8a556e5d"),
            (b"\xef" * 300, "f652d094525280bbd999630fb005505638d319191564aadda1260adbc12df8d1"),
        ):
            self.assertEqual(keccak(data).hex(), digest)
        # The ERC-1967 implementation slot is keccak256("eip1967.proxy.implementation") - 1.
        self.assertEqual("0x" + format(int.from_bytes(keccak(b"eip1967.proxy.implementation"),
                                                      "big") - 1, "064x"),
                         self.builder.IMPLEMENTATION_SLOT)

    def test_requires_the_etna_block(self):
        for value in (None, [], "etna"):
            self.setUp()
            if value is None:
                del self.config["etna"]
            else:
                self.config["etna"] = value
            self._assert_refused("predeploy config: etna must be an object")

    def test_refuses_etna_predeploys_off_their_constant_addresses(self):
        # The EL, the nodes and both guests build in getConstantAddress(chainId, 10003); a
        # predeploy generated elsewhere, here on chain 167's addresses, is never called.
        for name, expected in (("EtnaStaking", "0x1670010000000000000000000000000000010003"),
                               ("EtnaStakingImpl", "0x0167001000000000000000000000000000010003"),
                               ("BridgedTaikoToken", "0x1670010000000000000000000000000000000007"),
                               ("BridgedTaikoTokenImpl",
                                "0x0167001000000000000000000000000000000007")):
            self.setUp()
            moved = expected.replace("167001", "167000")
            self.config["contractAddresses"][name] = moved
            self.predeploys[moved] = self.predeploys.pop(self.addresses[name])
            self._assert_refused("predeploy config: " + name + " " + moved + " is not "
                                 r"getConstantAddress\(.*\) = " + expected)

    def test_refuses_staking_inbox_other_than_l1_inbox(self):
        other = "0x00000000000000000000000000000000000100dd"
        # The configuration must name the Inbox passed as --l1-inbox.
        self.l1_inbox = other
        self._assert_refused("predeploy config: etna.inbox must be the L1 Inbox " + other)
        # Both name another Inbox, but the alloc was generated for the old one.
        self._etna(inbox=other)
        self._assert_refused("EtnaStakingImpl inbox is "
                             + self.fixture.address_word(self.fixture.L1_INBOX) + ", not "
                             + self.fixture.address_word(other))
        # Or the alloc alone binds another Inbox, at both of the immutable's offsets.
        self.setUp()
        self.predeploys = self.fixture.predeploys(
            staking={"inbox": self.fixture.address_word(other)})
        self._assert_refused("EtnaStakingImpl inbox is " + self.fixture.address_word(other))
        self.setUp()
        self._etna(inbox=None)
        self._assert_refused("predeploy config: etna.inbox must be a non-zero address")

    def test_refuses_staking_token_other_than_bridged_taiko_proxy(self):
        token = self.fixture.address_word(self.addresses["BridgedTaikoToken"])
        for other in (self.addresses["BridgedTaikoTokenImpl"], self.fixture.L1_TAIKO_TOKEN,
                      "0x" + "00" * 20):
            self.setUp()
            self.predeploys = self.fixture.predeploys(
                staking={"token": self.fixture.address_word(other)})
            self._assert_refused("EtnaStakingImpl token is " + self.fixture.address_word(other)
                                 + ", not " + token)

    def test_refuses_withdrawal_delay_below_u_plus_two_plus_window(self):
        bound = r"is below etna.unsettledLimit \+ 2 \+ etna.evidenceWindowBlocks = 302402"
        self._etna(withdrawalDelay="302401")
        self._assert_refused("predeploy config: etna.withdrawalDelay 302401 " + bound)
        # An alloc generated with a shorter delay than the configuration states.
        self.setUp()
        self.predeploys = self.fixture.predeploys(
            staking={"withdrawalDelay": self.fixture.word(302401)})
        self._assert_refused("predeploys: EtnaStakingImpl withdrawalDelay 302401 " + bound)
        # The bound moves with either input.
        for field in ("unsettledLimit", "evidenceWindowBlocks"):
            self.setUp()
            self._etna(**{field: "151201"})
            self._assert_refused("etna.withdrawalDelay 302402 is below .* = 302403")
        for field, value, diagnostic in (
                ("unsettledLimit", "0", r"etna.unsettledLimit 0 is not in \[1, 262144\]"),
                ("unsettledLimit", "262145", r"etna.unsettledLimit 262145 is not in \[1, 262144\]"),
                ("evidenceWindowBlocks", "0", "etna.evidenceWindowBlocks must be positive")):
            self.setUp()
            self._etna(**{field: value})
            self._assert_refused("predeploy config: " + diagnostic)

    def test_accepts_withdrawal_delay_at_the_bound(self):
        # The example devnet's 302,402 is exactly 151,200 + 2 + 151,200.
        self.assertEqual(self.config["etna"]["withdrawalDelay"], "302402")
        alloc = self._build()["alloc"]
        implementation = self.addresses["EtnaStakingImpl"]
        self.assertEqual(alloc[implementation], self.predeploys[implementation])
        # A window one block shorter allows a delay one block shorter, again exactly the bound.
        self._etna(evidenceWindowBlocks="151199", withdrawalDelay="302401")
        self.predeploys = self.fixture.predeploys(
            staking={"withdrawalDelay": self.fixture.word(302401)})
        self._build()

    def test_refuses_each_constructor_bound(self):
        # Each bound EtnaStaking's constructor enforces, refused in the configuration and,
        # with the configuration intact, in the immutables of the generated alloc.
        cases = (
            ("nMax", 0, r"nMax 0 is not in \[1, 128\]"),
            ("nMax", 129, r"nMax 129 is not in \[1, 128\]"),
            ("vpUnit", 867_361_737, "vpUnit 867361737 is below 867361738"),
            ("minStake", 999_999_999, "minStake 999999999 is below vpUnit 1000000000"),
            ("minStake", 10**27 // 128 - 1, "minStake 7812499999999999999999999 times nMax 128 "
             r"is below 10\^27, TAIKO's supply"),
            ("missLimit", 0, r"missLimit 0 is not in \[1, 65535\]"),
            ("missLimit", 65_536, r"missLimit 65536 is not in \[1, 65535\]"),
            ("missSlashBps", 0, r"missSlashBps 0 is not in \[1, 10000\]"),
            ("missSlashBps", 10_001, r"missSlashBps 10001 is not in \[1, 10000\]"),
            ("slashBountyBps", 10_000, r"slashBountyBps 10000 is not in \[0, 9999\]"),
            ("forfeitBps", 0, r"forfeitBps 0 is not in \[1, 10000\]"),
            ("forfeitBps", 10_001, r"forfeitBps 10001 is not in \[1, 10000\]"),
            ("withdrawalDelay", 0, r"withdrawalDelay 0 is not in \[1, 281474976710655\]"),
            ("withdrawalDelay", 2**48, r"withdrawalDelay 281474976710656 is not in "
             r"\[1, 281474976710655\]"),
        )
        for field, value, diagnostic in cases:
            with self.subTest(field=field, value=value):
                self.setUp()
                self._etna(**{field: str(value)})
                self._assert_refused("predeploy config: etna." + diagnostic)
                self.setUp()
                self.predeploys = self.fixture.predeploys(staking={field: self.fixture.word(value)})
                self._assert_refused("predeploys: EtnaStakingImpl " + diagnostic)
        # A zero slash sink, which the constructor also refuses.
        self.setUp()
        self._etna(slashSink="0x" + "00" * 20)
        self._assert_refused("predeploy config: etna.slashSink must be a non-zero address")
        self.setUp()
        self.predeploys = self.fixture.predeploys(staking={"slashSink": self.fixture.word(0)})
        self._assert_refused("EtnaStakingImpl slashSink is " + self.fixture.word(0) + ", not "
                             + self.fixture.address_word(self.fixture.SLASH_SINK))
        # A slash sink that is the staking token, which the constructor also refuses.
        token = self.addresses["BridgedTaikoToken"]
        self.setUp()
        self._etna(slashSink=token)
        self._assert_refused("predeploy config: etna.slashSink must not be the staking token, the "
                             "BridgedTaikoToken proxy " + token.lower())
        self.setUp()
        self.predeploys = self.fixture.predeploys(
            staking={"slashSink": self.fixture.address_word(token)})
        self._assert_refused("EtnaStakingImpl slashSink is " + self.fixture.address_word(token)
                             + ", not " + self.fixture.address_word(self.fixture.SLASH_SINK))

    def test_refuses_etna_immutables_other_than_the_configuration(self):
        # Every immutable of both Etna implementations is pinned, also to values the constructor
        # would accept.
        word, address_word = self.fixture.word, self.fixture.address_word
        other = address_word("0x" + "cc" * 20)
        for staking, token, label, value in (
                ({"l1ChainId": word(1)}, None, "EtnaStakingImpl l1ChainId", word(1)),
                ({"minStake": word(7_812_500 * 10**18 + 1)}, None, "EtnaStakingImpl minStake",
                 word(7_812_500 * 10**18 + 1)),
                ({"vpUnit": word(10**9 + 1)}, None, "EtnaStakingImpl vpUnit", word(10**9 + 1)),
                ({"missLimit": word(3601)}, None, "EtnaStakingImpl missLimit", word(3601)),
                ({"missSlashBps": word(999)}, None, "EtnaStakingImpl missSlashBps", word(999)),
                ({"withdrawalDelay": word(302403)}, None, "EtnaStakingImpl withdrawalDelay",
                 word(302403)),
                ({"slashBountyBps": word(0)}, None, "EtnaStakingImpl slashBountyBps", word(0)),
                ({"forfeitBps": word(10_000)}, None, "EtnaStakingImpl forfeitBps", word(10_000)),
                ({"slashSink": other}, None, "EtnaStakingImpl slashSink", other),
                ({"__self": other}, None, "EtnaStakingImpl __self", other),
                ({"__resolver": other}, None, "EtnaStakingImpl __resolver", other),
                (None, {"__self": other}, "BridgedTaikoTokenImpl __self", other),
                (None, {"__resolver": other}, "BridgedTaikoTokenImpl __resolver", other)):
            with self.subTest(label=label):
                self.setUp()
                self.predeploys = self.fixture.predeploys(staking=staking, token=token)
                self._assert_refused(label + " is " + value + ", not .*rerun `pnpm genesis:gen`")

    def test_refuses_token_vault_other_than_erc20_vault_proxy(self):
        vault = self.fixture.address_word(self.addresses["ERC20Vault"])
        for other in (self.fixture.ERC20_VAULT_IMPL, self.addresses["EtnaStaking"],
                      "0x" + "00" * 20):
            self.setUp()
            self.predeploys = self.fixture.predeploys(
                token={"erc20Vault": self.fixture.address_word(other)})
            self._assert_refused("BridgedTaikoTokenImpl erc20Vault is "
                                 + self.fixture.address_word(other) + ", not " + vault)

    def test_refuses_owner_without_code_unless_devnet(self):
        # The staking owner is the DAO's execution address on L2, a contract. Only a devnet may
        # give it to a key, as the example devnet configuration does.
        owner = self.fixture.STAKING_OWNER
        self._build()
        self._etna(devnet=False, premint=[])
        self.predeploys = self.fixture.predeploys(premint=())
        self._assert_refused("predeploy config: etna.stakingOwner " + owner + " holds no code in "
                             "the genesis; outside a devnet it must be")
        self.base["alloc"][owner] = {"balance": "0x0", "code": "0x"}
        self._assert_refused("etna.stakingOwner " + owner + " holds no code")
        self.base["alloc"][owner] = {"balance": "0x0", "code": "0x6000"}
        alloc = self._build()["alloc"]
        self.assertEqual(alloc[owner]["code"], "0x6000")

    def test_refuses_devnet_on_public_chain_ids(self):
        for chain in (167000, 167009, 167013):
            self.setUp()
            self.base["config"]["chainId"] = chain
            self.config["chainId"] = chain
            self._assert_refused("predeploy config: etna.devnet is refused on chain " + str(chain))

    def test_refuses_premint_without_devnet(self):
        self._etna(devnet=False)
        self._assert_refused("predeploy config: etna.premint needs etna.devnet true: it mints L2 "
                             "TAIKO that no L1 TAIKO backs")

    def test_refuses_premint_above_supply(self):
        first, second = self.fixture.PREMINT[0][0], self.fixture.PREMINT[1][0]
        self._etna(premint=[{first: "500000000000000000000000000"},
                            {second: "500000000000000000000000001"}])
        self._assert_refused("predeploy config: etna.premint totals 1000000000000000000000000001, "
                             r"above 10\^27, TAIKO's supply")

    def test_refuses_malformed_etna_values(self):
        first = self.fixture.PREMINT[0][0]
        cases = (
            # Numbers are decimal strings, so no amount passes through a lossy JSON number.
            ({"nMax": 128}, "etna.nMax must be a decimal string"),
            ({"minStake": "0x67637d2d4c5b2400000000"}, "etna.minStake must be a decimal string"),
            ({"vpUnit": "01000000000"}, "etna.vpUnit must be a decimal string"),
            ({"missLimit": "-1"}, "etna.missLimit must be a decimal string"),
            ({"devnet": "true"}, "etna.devnet must be a JSON boolean"),
            ({"devnet": 1}, "etna.devnet must be a JSON boolean"),
            ({"premint": {first: "1"}}, "etna.premint must be an array"),
            ({"premint": [{first: "1", self.fixture.OTHER_ACCOUNT: "1"}]},
             r"each etna.premint entry must be one \{address: amount\} pair"),
            ({"premint": [{first: "0"}]}, "etna.premint amount of " + first + " must be positive"),
            ({"premint": [{first: 1}]}, "etna.premint amount of " + first
             + " must be a decimal string"),
            ({"premint": [{first: "1"}, {first.upper().replace("0X", "0x"): "1"}]},
             "etna.premint lists " + first + " twice"),
            ({"premint": [{"0x" + "00" * 20: "1"}]},
             "an etna.premint account must be a non-zero address"),
            ({"stakingOwner": "0x" + "00" * 20}, "etna.stakingOwner must be a non-zero address"),
            ({"l1TaikoToken": "0x1234"}, "etna.l1TaikoToken must be a non-zero address"),
        )
        for values, diagnostic in cases:
            with self.subTest(values=values):
                self.setUp()
                self._etna(**values)
                self._assert_refused("predeploy config: " + diagnostic)

    def test_refuses_vault_mapping_to_another_l1_token(self):
        other = "0x00000000000000000000000000000000000100dd"
        # The configuration must name the L1 TAIKO passed as --l1-taiko-token.
        self.l1_taiko_token = other
        self._assert_refused("predeploy config: etna.l1TaikoToken must be the L1 TAIKO token "
                             + other)
        # Both name another L1 token, but the vault maps the bridged TAIKO to the old one.
        self._etna(l1TaikoToken=other)
        self._assert_refused("the ERC20Vault must map the bridged TAIKO predeploy to the L1 "
                             "TAIKO token " + other + " on chain 3151908, but its storage slot "
                             + self.fixture.CANONICAL_SLOT + " is ")
        # Or the vault's storage alone maps it elsewhere, either way round.
        word = self.fixture.word
        for slot, value in (
                (self.fixture.CANONICAL_SLOT,
                 word(18 << 224 | int(other, 16) << 64 | self.fixture.L1_CHAIN_ID)),
                (self.fixture.CANONICAL_SLOT, word(18 << 224 | int(
                    self.fixture.L1_TAIKO_TOKEN, 16) << 64 | 1)),
                (self.fixture.BRIDGED_SLOT, word(0)),
                (self.fixture.BRIDGED_SLOT,
                 self.fixture.address_word(self.fixture.ERC20_VAULT_IMPL))):
            self.setUp()
            self.predeploys[self.addresses["ERC20Vault"]]["storage"][slot] = value
            self._assert_refused("the ERC20Vault must map .* storage slot " + slot + " is " + value)

    def test_refuses_unexpected_token_or_staking_storage(self):
        word, address_word = self.fixture.word, self.fixture.address_word
        _, amount, balance_slot = self.fixture.PREMINT[0]
        total = sum(entry[1] for entry in self.fixture.PREMINT)
        checkpoint = int(self.fixture.CHECKPOINT_SLOT, 16)
        cases = (
            # The bridged TAIKO proxy holds exactly what `init` and the premint's mints write.
            ("BridgedTaikoToken", self.fixture.OTHER_BALANCE_SLOT, word(1)),
            ("BridgedTaikoToken", balance_slot, word(amount + 1)),
            ("BridgedTaikoToken", word(303), word(total - 1)),
            ("BridgedTaikoToken", word(304), self.fixture.TAIKO_WORD),
            ("BridgedTaikoToken", word(305), word(0)),
            ("BridgedTaikoToken", word(353), word(0)),
            ("BridgedTaikoToken", word(354), self.fixture.TAIKO_WORD),
            ("BridgedTaikoToken", word(456), word(2)),
            ("BridgedTaikoToken", self.fixture.CHECKPOINT_SLOT, word(total << 32 | 1)),
            ("BridgedTaikoToken", word(checkpoint + 1), word(1)),
            # The EIP-712 hashed name, an allowance root, and the votes delegation mapping.
            ("BridgedTaikoToken", word(351), word(1)),
            ("BridgedTaikoToken", word(302), word(1)),
            ("BridgedTaikoToken", "0x" + "ab" * 32, word(1)),
            # The deprecated `__reentry` byte, which `init` never writes, and a paused token.
            ("BridgedTaikoToken", word(201), word(0x0101)),
            ("BridgedTaikoToken", word(201), word(0x0200)),
            ("BridgedTaikoToken", word(51), address_word(self.fixture.STAKING_OWNER)),
            ("BridgedTaikoToken", word(0), word(255)),
            # EtnaStaking holds nothing beyond initialized, owner, flags and implementation: no
            # snapshot height, seat, bond or record in its namespace.
            ("EtnaStaking", self.fixture.STAKING_NAMESPACE, word(1)),
            ("EtnaStaking", word(int(self.fixture.STAKING_NAMESPACE, 16) + 3), word(1)),
            ("EtnaStaking", word(1), word(1)),
            ("EtnaStaking", word(201), word(0x0101)),
            ("EtnaStaking", word(201), word(0x0200)),
            ("EtnaStaking", word(51), address_word(self.fixture.OWNER)),
            ("EtnaStaking", word(0), word(0)),
        )
        for proxy, slot, value in cases:
            with self.subTest(proxy=proxy, slot=slot, value=value):
                self.setUp()
                self.predeploys[self.addresses[proxy]]["storage"][slot] = value
                self._assert_refused("the " + proxy + " proxy's storage slot " + slot + " is "
                                     + value + ", not ")
        # A premint account without its balance.
        self.setUp()
        del self.predeploys[self.addresses["BridgedTaikoToken"]]["storage"][balance_slot]
        self._assert_refused("the BridgedTaikoToken proxy's storage slot " + balance_slot
                             + " is " + word(0) + ", not " + word(amount))
        # Without a premint, the token has no balance, supply or checkpoint.
        self.setUp()
        self._etna(premint=[])
        self._assert_refused("the BridgedTaikoToken proxy's storage slot ")
        self.predeploys = self.fixture.predeploys(premint=())
        self._build()
        # The implementations hold only the `_initialized` 255 their constructors leave.
        for implementation, slot, value in (("EtnaStakingImpl", word(0), word(1)),
                                            ("BridgedTaikoTokenImpl", word(51),
                                             address_word(self.fixture.OWNER))):
            self.setUp()
            self.predeploys[self.addresses[implementation]]["storage"][slot] = value
            self._assert_refused(implementation + "'s storage slot " + slot + " is " + value)

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

    def test_cli_rejects_an_open_checkpoint_store_without_output(self):
        self.config["usesBeaconRoots"] = False
        self._assert_cli_rejected(json.dumps(self.base), "usesBeaconRoots must be true")
        self.config["usesBeaconRoots"] = True
        self.predeploys = self.fixture.predeploys(usesBeaconRoots=self.fixture.word(0))
        self._assert_cli_rejected(json.dumps(self.base), "SignalServiceImpl usesBeaconRoots is")

    def test_cli_failure_prints_one_line_and_removes_old_output(self):
        # A failed run leaves no genesis behind, not even the one an earlier run wrote.
        self.config["usesBeaconRoots"] = False
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "genesis.json"
            output.write_text("{}")
            result, output = self._run_cli(directory, json.dumps(self.base))
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists(), "the earlier output must be gone")
            self.assertNotIn("Traceback", result.stderr)
            self.assertRegex(result.stderr.strip(), r"^build_etna_genesis.py: error: predeploy "
                             r"config: usesBeaconRoots must be true[^\n]*$")
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()),
                             ["base.json", "genesis_alloc.json", "genesis_config.json"],
                             "no temporary file left")

    def test_fixture_script_builds_through_the_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "genesis.json"
            result = subprocess.run([sys.executable, str(FIXTURE), "--output", str(output)],
                                    text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            alloc = json.loads(output.read_text())["alloc"]
            self.assertEqual(len(alloc), 11, "nine predeploys and two system contracts")

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
                                 "--l1-inbox", self.l1_inbox,
                                 "--l1-taiko-token", self.l1_taiko_token,
                                 "--artifacts", str(self.artifacts),
                                 "--output", str(output)],
                                text=True, capture_output=True, check=False)
        return result, output


if __name__ == "__main__":
    unittest.main()
