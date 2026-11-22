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
FROZEN = "f556fa94186b0ab604573e8d3a4c4d4fa835dc84"
LATEST = "3602629758beb653423a23608fd1960810efcfac"
PRODUCT = "2e6763e21bc236cfcda6011d164b32040f9e0c8d"
LATEST_DOCS = {
    "packages/protocol/docs/etna/SPEC.md": {
        "bytes": 284625,
        "gitBlob": "0b7f70096dc6250861a01209f30be7d23a7e234b",
        "sha256": "383760a1e7df211a9c74835a4e2446db57a05bd21eb52f030980afd205748d3c"
    },
    "packages/protocol/docs/etna/ACCEPTANCE.md": {
        "bytes": 60050,
        "gitBlob": "95d9569fc0954b9ba97abbddfe184c197811827a",
        "sha256": "7283c47bec643d3054a41ec3266ead387431b82ae3caa4102c4866dfc8b39a7b"
    },
    "packages/protocol/docs/etna/SWITCH.md": {
        "bytes": 25483,
        "gitBlob": "b8ff8e16b9b19614f6f8a572cda13c0192f5b2d8",
        "sha256": "a1652de6d0f57eae119bb26f6a5c63bab83f8dead41e6ad81021709a133d30d4"
    }
}
FROZEN_SCOPE_SHA256 = "40baba560d022244f57a6d034a117ca78662da8e34cf0ee07baae5738c82e2ee"


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

    def test_exact_fifth_bundle_preserves_all_four_previous_bundles_and_claims(self):
        bundles = copy.deepcopy(self.manifest["bundles"])
        self.assertEqual(bundles.pop(LATEST, None), LATEST_DOCS)
        self.assertEqual(canonical_sha(bundles), "d7a4dbf50cd5de37c7d8b27d0e60dbf6f993c9dff65d84841b89e5a2ebbe5bfc")
        self.assertEqual(canonical_sha(self.manifest["claims"]), "d127d53a73905b701d950d75c1021433f05de6c6dfc3e21a0b96394ab79ef958")

    def test_latest_source_scope_has_only_waiting_obligations(self):
        value = self.selector()(LATEST)
        self.assertEqual(value["bundleId"], LATEST)
        self.assertEqual(value["status"], "SOURCE_REVIEWED")
        self.assertEqual(value["disposition"], "source-review-only")
        self.assertEqual(value["execution"], "NOT_EVALUATED")
        self.assertEqual(value["supersedes"], PRODUCT)
        self.assertIsNone(value["evidence"])
        self.assertEqual(len(value["obligations"]), 14)
        self.assertEqual({row["id"] for row in value["obligations"]}, {
            "Y01", "Y02", "Y03", "Y04", "Y05", "Y06", "Y07", "STOCK_DEPLOYMENT",
            "SWITCH", "PUBLIC_HISTORY", "RESOURCES", "CHECKPOINT_TRUST", "SIGNER_SESSION", "ENCODINGS",
        })
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
            "Y02": {"RECOV-8-38", "RECOV-8-39"},
            "Y03": {"LAND-6.1-6", "LAND-6.1-10", "RECOV-8-27", "PROOF-6.2-17", "PROOF-6.2-32"},
            "Y05": {"COMM-4.3-3", "ENC-A-39a", "ENC-A-42", "COMM-4.3-10", "COMM-4.3-13"},
            "Y06": {"DATA-5.4-3", "DATA-5.4-5"},
            "Y07": {"DATA-5.4-3", "DATA-5.4-5", "RECOV-8.4-7"},
            "STOCK_DEPLOYMENT": {"CONS-3.1-9"},
            "CHECKPOINT_TRUST": {"SYNC-9-5", "SYNC-9-6a"},
            "SIGNER_SESSION": {"START-10-6", "SYNC-9-10", "RECOV-8.2-2"},
            "ENCODINGS": {"CONS-3.2-8", "CONS-3.2-9", "ENC-A-10a", "ENC-A-10b", "ENC-A-23b", "ENC-A-23c", "ENC-A-39a", "ENC-A-42"},
            "SWITCH": {"START-10-5", "START-10-5d", "SYNC-9-5a"},
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

    def test_frozen_source_scope_remains_independently_selectable_and_unchanged(self):
        value = self.selector()(FROZEN)
        self.assertEqual(value["bundleId"], FROZEN)
        self.assertEqual(value["status"], "SOURCE_REVIEWED")
        scope = {key: item for key, item in value.items() if key not in {"bundleId", "status"}}
        self.assertEqual(canonical_sha(scope), FROZEN_SCOPE_SHA256)
        self.assertEqual(len(scope["obligations"]), 11)

    def test_source_only_selector_refuses_invalid_scopes_even_with_recomputed_file_pin(self):
        original = json.loads(self.boundary.SOURCE_REVISION_PATH.read_bytes())
        mutations = []
        for revision in (FROZEN, LATEST):
            for field, value in (("execution", "PASS"), ("disposition", "current-model"),
                                 ("evidence", {}), ("supersedes", FROZEN),
                                 ("obligations", []), ("obligations", None)):
                bad = copy.deepcopy(original)
                bad["bundles"][revision][field] = value
                mutations.append(bad)
            for field, value in (("status", "COMPLETE"), ("ruleIds", []), ("scope", "")):
                bad = copy.deepcopy(original)
                bad["bundles"][revision]["obligations"][0][field] = value
                mutations.append(bad)
            bad = copy.deepcopy(original)
            bad["bundles"][revision]["obligations"].append(copy.deepcopy(bad["bundles"][revision]["obligations"][0]))
            mutations.append(bad)
        bad = copy.deepcopy(original)
        bad["bundles"]["0" * 40] = bad["bundles"].pop(FROZEN)
        mutations.append(bad)
        bad = copy.deepcopy(original)
        del bad["bundles"][FROZEN]
        mutations.append(bad)
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "source-review.json"
            for index, bad in enumerate(mutations):
                raw = json.dumps(bad).encode()
                target.write_bytes(raw)
                with self.subTest(mutation=index), patch.object(self.boundary, "SOURCE_REVISION_PATH", target), \
                        patch.object(self.boundary, "SOURCE_REVISION_SHA256", hashlib.sha256(raw).hexdigest()), \
                        self.assertRaises(ValueError):
                    self.selector()(LATEST)

    def test_duplicate_ledger_keys_refuse_even_with_recomputed_file_pin(self):
        original = self.boundary.SOURCE_REVISION_PATH.read_text()
        duplicate = original.replace('"bundles": {', '"bundles": {}, "bundles": {', 1)
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "source-review.json"
            target.write_text(duplicate)
            with patch.object(self.boundary, "SOURCE_REVISION_PATH", target), \
                    patch.object(self.boundary, "SOURCE_REVISION_SHA256", hashlib.sha256(duplicate.encode()).hexdigest()), \
                    self.assertRaisesRegex(ValueError, "duplicate"):
                self.selector()(LATEST)

    def test_source_only_selector_refuses_invalid_identifier_types(self):
        for bundle in (None, [], {}, 360, True):
            with self.subTest(bundle=bundle), self.assertRaises(ValueError):
                self.selector()(bundle)

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
