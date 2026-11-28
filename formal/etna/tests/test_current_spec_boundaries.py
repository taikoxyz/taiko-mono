"""Exact workspace identity and named historical observations for Etna runners."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / "conformance"
DOC_ROOT = "packages/protocol/docs/etna/"
DOCS = tuple(DOC_ROOT + file for file in ("SPEC.md", "ACCEPTANCE.md", "SWITCH.md"))
CANONICAL = "d18357214fab30ea512ae9858a11699806d72ba1"
REVIEWED = "9c832234b4681fbc5eccdbaf9c9303b7869f91f4"
CURRENT = "2e6763e21bc236cfcda6011d164b32040f9e0c8d"
FROZEN = "f556fa94186b0ab604573e8d3a4c4d4fa835dc84"
LATEST = "3602629758beb653423a23608fd1960810efcfac"
WORKSPACE_SPEC = {
    "6f7150d65ff7c4a8b46b719d2ed48e665a60e47a6d013a2994229e8119ff24a7": FROZEN,
    "383760a1e7df211a9c74835a4e2446db57a05bd21eb52f030980afd205748d3c": LATEST,
    "4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b": CANONICAL,
    "7875c10373114ca5eaa7b164d2bfa844b4f5bbbede2ebfa252bb59246efd96de": REVIEWED,
    "b331b3af7b42a4645ebe3e2b4f42e912e33508893a091c3c3c289c8fdbd53a70": CURRENT,
}
COMET = "0880b4d378f347ab16e54ec677ff50d803f37d62"
CONTRACTS = "89f419915de4b73bb57c53bf970f6dea9e8e8c8c"


def load_runner(name, conformance=ROOT):
    spec = importlib.util.spec_from_file_location("w01_" + name, conformance / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def workspace_documents():
    return {name: (ROOT.parents[2] / name).read_bytes() for name in DOCS}


def document_identity(raw):
    return {
        "bytes": len(raw),
        "gitBlob": hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest(),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def copy_conformance_checkout(checkout):
    formal = checkout / "formal/etna"
    shutil.copytree(ROOT.parent, formal, ignore=shutil.ignore_patterns("__pycache__"))
    for doc, raw in workspace_documents().items():
        target = checkout / doc
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    return formal / "conformance"


class CurrentSpecBoundaries(unittest.TestCase):
    def manifest(self):
        return json.loads((ROOT / "current_spec_boundaries.json").read_bytes())

    def require_workspace(self, workspace):
        raw = workspace_documents()
        expected = {name: document_identity(data) for name, data in raw.items()}
        commit = WORKSPACE_SPEC[expected[DOCS[0]]["sha256"]]
        self.assertEqual(workspace["bundleId"], commit)
        self.assertEqual(workspace["documents"], expected)
        self.assertEqual(workspace["status"], "SOURCE_REVIEWED")

    def require_receipt(self, receipt, consumer, claim, implementation):
        self.assertEqual(set(receipt), {"workspace", "claim", "evidence"},
                         f"{consumer} still reports a single-SPEC result")
        self.require_workspace(receipt["workspace"])
        self.assertEqual(receipt["claim"]["consumerId"], consumer)
        self.assertEqual(receipt["claim"]["claimId"], claim)
        self.assertEqual(receipt["claim"]["bundleId"], receipt["workspace"]["bundleId"])
        self.assertEqual(receipt["claim"]["disposition"], "historical-only")
        self.assertEqual(receipt["claim"]["execution"], "NOT_EVALUATED")
        self.assertEqual(receipt["evidence"]["specCommit"], CANONICAL)
        self.assertEqual(receipt["evidence"]["implementationCommit"], implementation)
        manifest_name = "comet.json" if implementation == COMET else "contracts.json"
        manifest = (ROOT / "manifests" / manifest_name).read_bytes()
        self.assertEqual(receipt["evidence"]["implementationManifestSha256"], hashlib.sha256(manifest).hexdigest())
        extra_pins = {"comet-signed": (), "comet-filepv": ("comet_filepv/pins.json",),
                      "registry-cases": ("registry_cases/pins.json", "pins.json")}[consumer]
        pin_paths = ("comet_signed/pins.json", *extra_pins)
        self.assertEqual(receipt["evidence"]["inputPinsSha256"], {
            name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in pin_paths
        })
        if consumer == "registry-cases":
            scenario_sources = {
                "double-sign": "EtnaRegistryDoubleSignReplay.t.sol",
                "lifecycle": "EtnaRegistryLifecycleCases.t.sol",
                "displacement": "EtnaRegistryDisplacementCases.t.sol",
                "atomicity": "EtnaRegistryAtomicityCases.t.sol",
            }
            sources = ("EtnaRegistryCasesBase.sol", "EtnaRegistryPublicReplay.t.sol", scenario_sources[claim])
            self.assertEqual(receipt["evidence"]["testSourcesSha256"], {
                "solidity/" + name: hashlib.sha256((ROOT / "solidity" / name).read_bytes()).hexdigest()
                for name in sources
            })

    def test_stock_signed_receipt_attributes_the_historical_public_votes(self):
        signed = load_runner("run_comet_signed")
        self.require_receipt(signed.campaign_inputs()[-1], "comet-signed", "public-votes", COMET)

    def test_registry_receipts_use_their_own_scenario_claims(self):
        registry = load_runner("run_registry_cases")
        for scenario in ("double-sign", "lifecycle", "displacement", "atomicity"):
            with self.subTest(scenario=scenario):
                self.require_receipt(registry.inputs(scenario)[-1], "registry-cases", scenario, CONTRACTS)

    def test_registry_inputs_pin_the_actual_historical_scenario_programs(self):
        with tempfile.TemporaryDirectory() as directory:
            conformance = copy_conformance_checkout(Path(directory))
            registry = load_runner("run_registry_cases", conformance)
            pins = (conformance / "registry_cases/pins.json").read_bytes()
            for scenario, file in (("lifecycle", "EtnaRegistryLifecycleCases.t.sol"),
                                   ("atomicity", "EtnaRegistryAtomicityCases.t.sol")):
                with self.subTest(scenario=scenario):
                    expected = registry.inputs(scenario)[-1]
                    source = conformance / "solidity" / file
                    original = source.read_bytes()
                    self.assertTrue(original.endswith(b"\n"))
                    source.write_bytes(original[:-1] + b" ")
                    try:
                        with self.assertRaisesRegex(ValueError, "historical runner evidence differs"):
                            registry.inputs(scenario)
                    finally:
                        source.write_bytes(original)
                    self.assertEqual((conformance / "registry_cases/pins.json").read_bytes(), pins)
                    self.assertEqual(registry.inputs(scenario)[-1], expected)

    def test_registry_staging_checks_actual_copies_against_frozen_watches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            conformance = copy_conformance_checkout(root / "checkout")
            registry = load_runner("run_registry_cases", conformance)
            _, _, watched, _, _, _ = registry.inputs("atomicity")
            source = root / "contracts"
            config = "packages/protocol/foundry.toml"
            raw = b"[profile.default]\nffi = true\n"
            (source / config).parent.mkdir(parents=True)
            (source / config).write_bytes(raw)
            manifest = dict(schema="etna-source-snapshot-1", commit="a" * 40,
                            files={config: document_identity(raw)})
            name = "EtnaRegistryAtomicityCases.t.sol"
            harness = conformance / "solidity" / name
            original = harness.read_bytes()

            def stage(label):
                return registry.stage_inputs(root / label, source, manifest, {}, {},
                                             scenario="atomicity", watched=watched)

            self.assertEqual((stage("baseline")[1] / name).read_bytes(), original)
            harness.write_bytes(original[:-1] + b" ")
            try:
                with self.assertRaisesRegex(ValueError, "input hash differs: " + name):
                    stage("changed")
            finally:
                harness.write_bytes(original)
            self.assertEqual((stage("restored")[1] / name).read_bytes(), original)

    def test_filepv_receipts_use_their_own_scenario_claims(self):
        filepv = load_runner("run_comet_filepv")
        for scenario in ("persistence", "handler"):
            with self.subTest(scenario=scenario):
                self.require_receipt(filepv.inputs(scenario)[-1], "comet-filepv", scenario, COMET)

    def test_exact_source_bytes_and_each_partial_or_unknown_read(self):
        boundary = load_runner("current_spec")
        raw, manifest = workspace_documents(), self.manifest()
        self.require_workspace(boundary.classify_workspace_documents(raw, manifest))
        for path in DOCS:
            missing = {name: data for name, data in raw.items() if name != path}
            changed = raw | {path: raw[path][:-1] + bytes([raw[path][-1] ^ 1])}
            for candidate in (missing, changed, raw | {path: b"unknown"}):
                with self.subTest(path=path, keys=list(candidate)), self.assertRaises(ValueError):
                    boundary.classify_workspace_documents(candidate, manifest)
        with self.assertRaises(ValueError):
            boundary.classify_workspace_documents(raw | {DOC_ROOT + "README.md": b"extra"}, manifest)

    def test_pins_cannot_rebind_one_document_without_a_source_review(self):
        boundary = load_runner("current_spec")
        raw, manifest = workspace_documents(), self.manifest()
        active = WORKSPACE_SPEC[document_identity(raw[DOCS[0]])["sha256"]]
        other = CURRENT if active != CURRENT else REVIEWED
        changed = copy.deepcopy(manifest)
        changed["bundles"][other][DOCS[1]] = changed["bundles"][active][DOCS[1]]
        with self.assertRaises(ValueError):
            boundary.classify_workspace_documents(raw, changed)
        forged = raw | {DOCS[2]: raw[DOCS[2]] + b"\n"}
        changed = copy.deepcopy(manifest)
        changed["bundles"][active][DOCS[2]] = document_identity(forged[DOCS[2]])
        with self.assertRaises(ValueError):
            boundary.classify_workspace_documents(forged, changed)

    def test_disposition_controls_cannot_reclassify_unchanged_execution_inputs(self):
        boundary = load_runner("current_spec")
        registry_runner = load_runner("run_registry_cases")
        raw, manifest = workspace_documents(), self.manifest()
        observed = boundary.classify_workspace_documents(raw, manifest)
        registry = manifest["claims"]["registry-cases"]
        for mutation in ("swap", "promote", "omit"):
            changed = copy.deepcopy(manifest)
            claims = changed["claims"]["registry-cases"]
            if mutation == "swap":
                claims["lifecycle"], claims["displacement"] = registry["displacement"], registry["lifecycle"]
            elif mutation == "promote":
                claims["displacement"]["disposition"] = "current-model"
            else:
                del changed["claims"]["historical-models"]["registry-model"]
            self.assertEqual(boundary.classify_workspace_documents(raw, changed), observed)
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                metadata_path = Path(directory) / "boundaries.json"
                metadata_path.write_text(json.dumps(changed))
                with patch.object(boundary, "MANIFEST_PATH", metadata_path), self.assertRaises(ValueError):
                    boundary.select_claim(CURRENT, "registry-cases", "displacement")
                with patch.object(registry_runner.STOCK.CURRENT_SPEC, "MANIFEST_PATH", metadata_path):
                    with self.assertRaisesRegex(ValueError, "claims inventory differs"):
                        registry_runner.inputs("displacement")

    def test_executed_grid_model_is_named_and_omission_refuses_signed_inputs(self):
        signed = load_runner("run_comet_signed")
        manifest = self.manifest()
        consumer, claim = "historical-conformance", "grid-replays"
        expected = "conformance/EtnaSettlementReplay.tla"
        scope = signed.CURRENT_SPEC.select_claim(CURRENT, consumer, claim)
        self.assertIn(expected, scope["artifacts"])
        actual = signed.campaign_inputs()[-1]
        manifest["claims"][consumer][claim]["artifacts"].remove(expected)
        with tempfile.TemporaryDirectory() as directory:
            metadata_path = Path(directory) / "boundaries.json"
            metadata_path.write_text(json.dumps(manifest))
            with patch.object(signed.CURRENT_SPEC, "MANIFEST_PATH", metadata_path):
                with self.assertRaisesRegex(ValueError, "claims inventory differs"):
                    signed.campaign_inputs()
        self.assertEqual(signed.campaign_inputs()[-1], actual)

    def test_selector_never_uses_another_consumers_claim_or_unknown_workspace(self):
        boundary = load_runner("current_spec")
        for selection in ((CURRENT, "registry-cases", "public-votes"),
                          (CURRENT, "comet-signed", "displacement"),
                          (CURRENT, "registry-cases", "unknown"),
                          (CURRENT, "unknown", "displacement"),
                          ("0" * 40, "registry-cases", "displacement")):
            with self.subTest(selection=selection), self.assertRaises(ValueError):
                boundary.select_claim(*selection)


    def test_current_targets_select_only_a_source_scope(self):
        boundary = load_runner("current_spec")
        for consumer, claim, expected in (
            ("registry-vacancy-model", "lowest-empty-slot", "current-model"),
            ("registry-supply-model", "bounded-recycling", "current-model"),
            ("comet-validator-state", "stock-app-hash", "selected-public-operation"),
            ("comet-signer-transport", "cached-replies", "selected-public-operation"),
            ("proof-progress-model", "arbitrary-height-landing", "current-model"),
            ("rules-schedule-model", "timestamp-stop", "current-model"),
            ("current-implementation", "app-and-import", "waiting"),
        ):
            with self.subTest(consumer=consumer):
                selected = boundary.select_claim(CURRENT, consumer, claim)
                self.assertEqual(selected["disposition"], expected)
                self.assertEqual(selected["execution"], "NOT_EVALUATED")
                self.assertIsNone(selected["evidence"])
                for old_bundle in (CANONICAL, REVIEWED):
                    with self.assertRaisesRegex(ValueError, "requires the current reviewed workspace"):
                        boundary.select_claim(old_bundle, consumer, claim)

    def test_boundary_product_inventory_retains_every_old_claim_and_bundle(self):
        manifest = self.manifest()
        old_claims = manifest["claims"].copy()
        added = old_claims.pop("boundary-products", {})
        self.assertEqual(set(added), {
            "timestamp-projection", "repeated-recovery", "mixed-rule-landing", "funded-forfeiture",
            "registry-origin-selection", "terminal-seen-commit", "evidence-lifecycle",
        })
        for inventory, expected in (
            (old_claims, "5f9bd8672e8a183c071609a903ff532adc7da31ed51f8e9cda8efcadca8e8603"),
            ({key: value for key, value in manifest["bundles"].items() if key not in {LATEST, FROZEN}},
             "69ca7e52249cab3d6490b74e3abf5dc6df97277e44ef37fe41bdaac256d6042e"),
        ):
            self.assertEqual(hashlib.sha256(json.dumps(inventory, sort_keys=True,
                                                       separators=(",", ":")).encode()).hexdigest(), expected)

    def test_boundary_product_selector_accepts_every_reviewed_current_claim(self):
        boundary = load_runner("current_spec")
        for claim in ("timestamp-projection", "repeated-recovery", "mixed-rule-landing", "funded-forfeiture",
                      "registry-origin-selection", "terminal-seen-commit", "evidence-lifecycle"):
            with self.subTest(claim=claim):
                try:
                    selected = boundary.select_claim(CURRENT, "boundary-products", claim)
                except ValueError as error:
                    self.fail(str(error))
                self.assertEqual(selected["claimId"], claim)
                self.assertEqual(selected["execution"], "NOT_EVALUATED")
                self.assertIsNone(selected["evidence"])
                for old_bundle in (CANONICAL, REVIEWED):
                    with self.assertRaisesRegex(ValueError, "requires the current reviewed workspace"):
                        boundary.select_claim(old_bundle, "boundary-products", claim)

    def boundary_scope(self):
        self.assertTrue((ROOT / "boundary_scope.py").is_file(), "boundary product workspace selector is missing")
        with patch("sys.path", [str(ROOT), *sys.path]):
            return load_runner("boundary_scope")

    def test_boundary_scope_classifies_the_effective_workspace(self):
        scope = self.boundary_scope()
        checkout = ROOT.parents[2]
        active = WORKSPACE_SPEC[document_identity((checkout / DOCS[0]).read_bytes())["sha256"]]
        if active == CURRENT:
            for fixed in ("timestamp-projection", "repeated-recovery"):
                receipt = scope.reviewed_boundary(checkout, fixed)
                self.assertEqual(set(receipt), {"workspace", "claim"})
                self.require_workspace(receipt["workspace"])
                self.assertEqual(receipt["claim"]["claimId"], fixed)
                self.assertEqual(receipt["claim"]["execution"], "NOT_EVALUATED")
        else:
            with self.assertRaisesRegex(ValueError, "requires the current reviewed workspace"):
                scope.reviewed_boundary(checkout, "timestamp-projection")
        with self.assertRaises(ValueError):
            scope.reviewed_boundary(checkout, "unknown")

    def test_boundary_scope_refuses_unknown_documents_and_old_claim_drift(self):
        self.boundary_scope()
        with tempfile.TemporaryDirectory() as directory:
            checkout = Path(directory)
            conformance = copy_conformance_checkout(checkout)
            with patch("sys.path", [str(ROOT), *sys.path]):
                scope = load_runner("boundary_scope", conformance)
            doc = checkout / DOCS[1]
            original = doc.read_bytes()
            doc.write_bytes(original + b"\n")
            try:
                with self.assertRaisesRegex(ValueError, "do not match one reviewed revision"):
                    scope.reviewed_boundary(checkout, "timestamp-projection")
            finally:
                doc.write_bytes(original)
            changed = self.manifest()
            changed["claims"]["registry-cases"]["displacement"]["scope"] += " drift"
            manifest = conformance / "current_spec_boundaries.json"
            original = manifest.read_bytes()
            manifest.write_text(json.dumps(changed))
            try:
                with patch.object(scope.current_spec, "MANIFEST_PATH", manifest), \
                        self.assertRaisesRegex(ValueError, "claims inventory differs"):
                    scope.reviewed_boundary(checkout, "timestamp-projection")
            finally:
                manifest.write_bytes(original)

if __name__ == "__main__":
    unittest.main()
