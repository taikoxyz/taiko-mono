"""A new source revision cannot inherit an older product's execution credit."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / "conformance"
LATEST = "f556fa94186b0ab604573e8d3a4c4d4fa835dc84"
PRODUCT = "2e6763e21bc236cfcda6011d164b32040f9e0c8d"
LATEST_DOCS = {
    "packages/protocol/docs/etna/SPEC.md": {"bytes": 261010, "gitBlob": "5ec7c3e74c0590b9cad89c9ac5ce24e6423e5682", "sha256": "6f7150d65ff7c4a8b46b719d2ed48e665a60e47a6d013a2994229e8119ff24a7"},
    "packages/protocol/docs/etna/ACCEPTANCE.md": {"bytes": 51711, "gitBlob": "8e822391b6061951b3a3e7b969c1d51edf63ce1d", "sha256": "1ee58f0600daebc8277c6456145a9112388ae3f7c93efdba4d7618d04debdae4"},
    "packages/protocol/docs/etna/SWITCH.md": {"bytes": 27213, "gitBlob": "00f31974304ad68c0e3c4d2a1c3d40e2b0d15792", "sha256": "c33db855c674b1907480403a8ad54497e05fb1ca32d9772a15d97e2ffc61e14e"},
}


def load_boundary():
    spec = importlib.util.spec_from_file_location("revision_boundary", ROOT / "current_spec.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


class SourceRevisionRefresh(unittest.TestCase):
    def setUp(self):
        self.boundary = load_boundary()
        self.manifest = json.loads((ROOT / "current_spec_boundaries.json").read_bytes())

    def selector(self):
        method = getattr(self.boundary, "select_source_revision", None)
        self.assertTrue(callable(method), "new revisions need a separate source-only scope")
        return method

    def test_latest_source_does_not_change_product_qualification_revision(self):
        self.assertEqual(self.boundary.CURRENT_BUNDLE, PRODUCT)
        self.assertEqual(getattr(self.boundary, "LATEST_SOURCE_BUNDLE", None), LATEST)

    def test_exact_fourth_bundle_preserves_all_three_previous_bundles_and_claims(self):
        bundles = copy.deepcopy(self.manifest["bundles"])
        self.assertEqual(bundles.pop(LATEST, None), LATEST_DOCS)
        self.assertEqual(canonical_sha(bundles), "69ca7e52249cab3d6490b74e3abf5dc6df97277e44ef37fe41bdaac256d6042e")
        self.assertEqual(canonical_sha(self.manifest["claims"]), "d127d53a73905b701d950d75c1021433f05de6c6dfc3e21a0b96394ab79ef958")

    def test_latest_source_scope_has_only_waiting_obligations(self):
        value = self.selector()(LATEST)
        self.assertEqual(value["bundleId"], LATEST)
        self.assertEqual(value["status"], "SOURCE_REVIEWED")
        self.assertEqual(value["disposition"], "source-review-only")
        self.assertEqual(value["execution"], "NOT_EVALUATED")
        self.assertEqual(value["supersedes"], PRODUCT)
        self.assertIsNone(value["evidence"])
        self.assertGreaterEqual(len(value["obligations"]), 7)
        for item in value["obligations"]:
            self.assertEqual(item["status"], "WAITING")
            self.assertTrue(item["ruleIds"])
            self.assertTrue(item["scope"])

    def test_every_nonhistorical_claim_refuses_latest_revision(self):
        self.assertIn(LATEST, self.manifest["bundles"])
        count = 0
        for consumer, claims in self.manifest["claims"].items():
            for name, claim in claims.items():
                if claim["disposition"] != "historical-only":
                    count += 1
                    with self.subTest(consumer=consumer, claim=name), self.assertRaisesRegex(ValueError, "requires the current reviewed workspace"):
                        self.boundary.select_claim(LATEST, consumer, name)
                    selected = self.boundary.select_claim(PRODUCT, consumer, name)
                    self.assertEqual(selected["execution"], "NOT_EVALUATED")
        self.assertGreater(count, 0)

    def test_historical_claims_keep_their_original_evidence_at_latest_workspace(self):
        self.assertIn(LATEST, self.manifest["bundles"])
        for consumer, claims in self.manifest["claims"].items():
            for name, claim in claims.items():
                if claim["disposition"] == "historical-only":
                    previous = self.boundary.select_claim(PRODUCT, consumer, name)
                    latest = self.boundary.select_claim(LATEST, consumer, name)
                    self.assertEqual(latest | {"bundleId": PRODUCT}, previous)

    def test_obligations_name_the_direct_rules_they_leave_unverified(self):
        selected = self.selector()(LATEST)
        rows = {item["id"]: set(item["ruleIds"]) for item in selected["obligations"]}
        required = {
            "Y02": {"RECOV-8-38", "RECOV-8.1-7"},
            "Y03": {"LAND-6.1-6", "LAND-6.1-10", "RECOV-8-27"},
            "Y05": {"COMM-4.3-3"},
            "Y06": {"DATA-5.4-3", "DATA-5.4-5"},
            "Y07": {"DATA-5.4-3", "DATA-5.4-5", "RECOV-8.4-7"},
            "STOCK_DEPLOYMENT": {"CONS-3.1-9"},
        }
        for name, rules in required.items():
            with self.subTest(obligation=name):
                self.assertTrue(rules <= rows[name], "missing direct source rules: " + str(rules - rows[name]))

    def test_source_only_selector_rejects_other_versions_and_changed_ledger(self):
        method = self.selector()
        for bundle in (PRODUCT, "0" * 40, True):
            with self.subTest(bundle=bundle), self.assertRaises(ValueError):
                method(bundle)
        original = self.boundary.SOURCE_REVISION_PATH.read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "source-review.json"
            target.write_bytes(original + b"\n")
            with patch.object(self.boundary, "SOURCE_REVISION_PATH", target), self.assertRaises(ValueError):
                method(LATEST)

    def test_changed_latest_document_pin_cannot_grant_a_workspace_identity(self):
        changed = copy.deepcopy(self.manifest)
        self.assertIn(LATEST, changed["bundles"])
        changed["bundles"][LATEST][next(iter(LATEST_DOCS))]["bytes"] += 1
        raw = {name: (ROOT.parents[2] / name).read_bytes() for name in self.boundary.DOCUMENT_PATHS}
        with self.assertRaisesRegex(ValueError, "bundles inventory differs"):
            self.boundary.classify_workspace_documents(raw, changed)

    def test_effective_workspace_never_upgrades_latest_source_review_to_product_claim(self):
        raw = {name: (ROOT.parents[2] / name).read_bytes() for name in self.boundary.DOCUMENT_PATHS}
        workspace = self.boundary.classify_workspace_documents(raw, self.manifest)
        if workspace["bundleId"] == LATEST:
            self.assertEqual(workspace["documents"], LATEST_DOCS)
            self.assertEqual(self.selector()(workspace["bundleId"])["execution"], "NOT_EVALUATED")
            with self.assertRaises(ValueError):
                self.boundary.select_claim(workspace["bundleId"], "boundary-products", "evidence-lifecycle")
        else:
            self.assertIn(workspace["bundleId"], self.manifest["bundles"])
            self.assertNotEqual(workspace["bundleId"], LATEST)


if __name__ == "__main__":
    unittest.main()
