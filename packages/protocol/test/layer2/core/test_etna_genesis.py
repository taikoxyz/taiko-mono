"""Regression tests for the alloc-only Etna genesis builder (stdlib only)."""
import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PROTOCOL = Path(__file__).resolve().parents[3]
SCRIPT = PROTOCOL / "script/layer2/build_etna_genesis.py"
ARTIFACT = PROTOCOL / "out/layer2/L2FeeVault.sol/L2FeeVault.json"


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
        # Real compiler metadata; Foundry integration separately supplies actual EVM-exported code.
        # Run `FOUNDRY_PROFILE=layer2 forge build` before this stdlib-only parser suite.
        self.artifact = self.builder.load(ARTIFACT)
        contract = next(n for n in self.artifact["ast"]["nodes"]
                        if n.get("nodeType") == "ContractDefinition" and n["name"] == "L2FeeVault")
        self.immutables = {n["name"]: n for n in contract["nodes"]
                           if n.get("mutability") == "immutable"}
        template = bytearray.fromhex(self.artifact["deployedBytecode"]["object"][2:])
        for name, value in (("l1ChainId", 1), ("l1Inbox", int("11" * 20, 16))):
            for ref in self.artifact["deployedBytecode"]["immutableReferences"][str(self.immutables[name]["id"])]:
                template[ref["start"]:ref["start"] + ref["length"]] = value.to_bytes(32, "big")
        self.runtime = {"l1ChainId": "1", "l1Inbox": "0x" + "11" * 20,
                        "runtime": "0x" + template.hex()}

    def test_rejects_unbound_hex_runtime(self):
        for code in ("0x60016000", self.artifact["deployedBytecode"]["object"]):
            with self.subTest(code=code[:20]), self.assertRaises(ValueError):
                self.builder.build(self.base, dict(self.runtime, runtime=code), self.artifact)

    def test_discards_stale_state_root(self):
        self.base["stateRoot"] = "0x" + "aa" * 32
        result = self.builder.build(self.base, self.runtime, self.artifact)
        self.assertNotIn("stateRoot", result)

    def test_build_is_alloc_only_reproducible_and_zero_balance(self):
        self.base["stateRoot"] = "0x" + "aa" * 32
        before = json.loads(json.dumps(self.base))
        first = self.builder.build(self.base, self.runtime, self.artifact)
        second = self.builder.build(self.base, self.runtime, self.artifact)
        self.assertEqual(first, second)
        self.assertEqual(self.base, before, "builder must not mutate input")
        self.assertEqual({k: v for k, v in first.items() if k != "alloc"},
                         {k: v for k, v in before.items() if k not in ("alloc", "stateRoot")})
        self.assertEqual(first["alloc"]["0xabcdef0000000000000000000000000000000000"], {"balance": "123"})
        vault = first["alloc"]["0x1670010000000000000000000000000000010001"]
        self.assertEqual(vault, {"balance": "0x0", "nonce": "0x1", "code": self.runtime["runtime"]})
        self.assertEqual(first["alloc"][self.builder.ROOTS]["code"], self.builder.ROOTS_RUNTIME)
        self.assertEqual(first["alloc"][self.builder.HISTORY]["code"], self.builder.HISTORY_RUNTIME)

    def test_replaces_prefixed_and_uppercase_target_allocs(self):
        target = "1670010000000000000000000000000000010001"
        self.base["alloc"][target.upper()] = {"balance": "99", "code": "0xffff"}
        result = self.builder.build(self.base, self.runtime, self.artifact)
        self.assertNotIn(target, result["alloc"])
        self.assertEqual(result["alloc"]["0x" + target]["balance"], "0x0")
        self.assertEqual(len(result["alloc"]), 4)

    def test_chain_id_changes_treasury_and_runtime_changes_alloc(self):
        changed = json.loads(json.dumps(self.base))
        changed["config"]["chainId"] = 167002
        result = self.builder.build(changed, self.runtime, self.artifact)
        self.assertIn("0x1670020000000000000000000000000000010001", result["alloc"])
        self.assertNotEqual(result, self.builder.build(self.base, self.runtime, self.artifact))
        altered = dict(self.runtime, runtime="0x60026000")
        with self.assertRaises(ValueError):
            self.builder.build(self.base, altered, self.artifact)

    def test_rejects_ambiguous_allocs_invalid_identity_and_runtime(self):
        self.base["alloc"]["0xabcdef0000000000000000000000000000000000"] = {"balance": "456"}
        with self.assertRaises(ValueError):
            self.builder.build(self.base, self.runtime, self.artifact)
        self.base["alloc"] = {}
        for field, value in (("l1ChainId", "0"), ("l1ChainId", str(2**256)),
                             ("l1ChainId", 1.5), ("l1ChainId", True), ("l1Inbox", "0x" + "00" * 20),
                             ("runtime", "0x"), ("runtime", "0x123"), ("runtime", "0xzz")):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.builder.build(self.base, dict(self.runtime, **{field: value}), self.artifact)

    def test_cli_rejects_identity_changes_and_incomplete_or_mutated_runtime_without_output(self):
        refs = self.artifact["deployedBytecode"]["immutableReferences"]
        chain_refs = refs[str(self.immutables["l1ChainId"]["id"])]
        partial = bytearray.fromhex(self.runtime["runtime"][2:])
        partial[chain_refs[0]["start"]:chain_refs[0]["start"] + 32] = (2).to_bytes(32, "big")
        altered_code = "0x00" + self.runtime["runtime"][4:]
        variants = [dict(self.runtime, l1ChainId="2"),
                    dict(self.runtime, l1Inbox="0x" + "22" * 20),
                    dict(self.runtime, l1ChainId="2", runtime="0x" + partial.hex()),
                    dict(self.runtime, runtime=altered_code),
                    dict(self.runtime, runtime=self.artifact["deployedBytecode"]["object"]),
                    dict(self.runtime, runtime="0x60016000"),
                    dict(self.runtime, l1ChainId=str(2**256))]
        for runtime in variants:
            with self.subTest(runtime=runtime["runtime"][:20], chain=runtime["l1ChainId"]):
                self._assert_cli_rejected(json.dumps(self.base), json.dumps(runtime), "ValueError")

    def test_cli_rejects_malformed_artifacts_without_output(self):
        chain_id = str(self.immutables["l1ChainId"]["id"])
        inbox_id = str(self.immutables["l1Inbox"]["id"])
        variants = []

        def variant():
            artifact = copy.deepcopy(self.artifact)
            variants.append(artifact)
            return artifact

        variant().pop("ast")
        variant()["ast"]["absolutePath"] = "contracts/Untrusted.sol"
        variant()["metadata"]["settings"]["compilationTarget"] = {"contracts/Untrusted.sol": "L2FeeVault"}
        variant()["deployedBytecode"]["linkReferences"] = {"Untrusted.sol": {"Lib": []}}
        variant()["deployedBytecode"]["object"] = "0x__$unlinked$__"
        variant()["deployedBytecode"]["immutableReferences"] = {}
        variant()["deployedBytecode"]["immutableReferences"]["999999999"] = [{"start": 0, "length": 32}]
        variant()["deployedBytecode"]["immutableReferences"][chain_id] = []
        variant()["deployedBytecode"]["immutableReferences"][chain_id] = None
        for ref in ({"start": -1, "length": 32}, {"start": 999999, "length": 32},
                    {"start": 0, "length": 31}, {"start": True, "length": 32},
                    {"start": 1.5, "length": 32}, {"start": 0}, None):
            variant()["deployedBytecode"]["immutableReferences"][chain_id] = [ref]
        artifact = variant()
        artifact["deployedBytecode"]["immutableReferences"][inbox_id] = artifact["deployedBytecode"]["immutableReferences"][chain_id]
        for field, value in (("name", "other"), ("id", self.immutables["l1Inbox"]["id"]),
                             ("stateVariable", False), ("typeDescriptions", {"typeString": "uint64"})):
            artifact = variant()
            contract = next(n for n in artifact["ast"]["nodes"] if n.get("name") == "L2FeeVault")
            declaration = next(n for n in contract["nodes"] if n.get("name") == "l1ChainId")
            declaration[field] = value
        for index, artifact in enumerate(variants):
            with self.subTest(index=index):
                self._assert_cli_rejected(json.dumps(self.base), json.dumps(self.runtime),
                                          "ValueError", artifact)

    def test_rejects_system_runtime_hash_drift(self):
        original = self.builder.ROOTS_RUNTIME
        try:
            self.builder.ROOTS_RUNTIME = "0x6000"
            with self.assertRaises(ValueError):
                self.builder.build(self.base, self.runtime, self.artifact)
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
            expected = (json.dumps(self.builder.build(self.base, self.runtime, self.artifact),
                                   sort_keys=True, indent=2) + "\n").encode()
            self.assertEqual(output.read_bytes(), expected)

    def _assert_cli_rejected(self, raw_base, raw_runtime, diagnostic="duplicate JSON key", artifact=None):
        with tempfile.TemporaryDirectory() as directory:
            result, output = self._run_cli(directory, raw_base, raw_runtime, artifact)
            self.assertFalse(output.exists(), "ambiguous input must not create genesis output")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(diagnostic, result.stderr)

    def _run_cli(self, directory, raw_base, raw_runtime, artifact=None):
        base = Path(directory) / "base.json"
        runtime = Path(directory) / "runtime.json"
        output = Path(directory) / "genesis.json"
        artifact_path = Path(directory) / "artifact.json"
        artifact_path.write_text(json.dumps(self.artifact if artifact is None else artifact))
        base.write_text(raw_base)
        runtime.write_text(raw_runtime)
        result = subprocess.run([sys.executable, str(SCRIPT), "--base", str(base),
                                 "--runtime", str(runtime), "--vault-artifact", str(artifact_path),
                                 "--output", str(output)],
                                text=True, capture_output=True, check=False)
        return result, output

    def test_write_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "genesis.json"
            genesis = self.builder.build(self.base, self.runtime, self.artifact)
            self.builder.write(genesis, destination)
            first = destination.read_bytes()
            self.builder.write(genesis, destination)
            self.assertEqual(first, destination.read_bytes())
            self.assertTrue(first.endswith(b"\n"))


if __name__ == "__main__":
    unittest.main()
