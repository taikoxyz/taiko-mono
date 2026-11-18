"""Static profile contracts; these checks do not establish model behavior."""

import hashlib
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("async_check", ROOT / "check.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
PRODUCT = ROOT / "products/proving-async"

GUARDS = {"PastReference", "PastFinalization", "BlockEndCheckpoint", "CheckGeneration",
          "CheckFullData", "CheckBackendBinding", "CorrectActualParent", "CandidateAnchorGuard"}
DISABLED = {"CreditIncluded", "CreditProved", "AllowReferenceRewrite", "AllowGenerationRewrite"}
WITNESSES = {"retry": "AsyncRetryNotReached", "cached": "AsyncCachedLandNotReached",
             "short": "AsyncShortNotReached", "suffix": "AsyncSuffixNotReached"}


def constants(text):
    return dict(re.findall(r'^\s*(\w+)\s*=\s*(\S+)\s*$', text, re.MULTILINE))


class ProfileTests(unittest.TestCase):
    def test_profiles_are_explicit_opt_in(self):
        self.assertTrue((ROOT / "EtnaProvingAsyncProduct.tla").is_file())
        self.assertTrue(PRODUCT.is_dir())
        self.assertFalse(any("EtnaProvingAsyncProduct" in p.read_text() for p in (ROOT / "configs").glob("*.cfg")))

    def test_normals_keep_all_promised_dimensions_and_guards(self):
        for capacity in (1, 2):
            with self.subTest(capacity=capacity):
                text = (PRODUCT / f"cap{capacity}-normal.cfg").read_text()
                self.assertEqual(CHECK.parse_expectation(text), "PASS")
                self.assertEqual(CHECK.parse_module(text), "EtnaProvingAsyncProduct")
                self.assertIn("SPECIFICATION AsyncSpec", text)
                values = constants(text)
                for name in GUARDS:
                    self.assertEqual(values[name], "TRUE")
                for name in DISABLED:
                    self.assertEqual(values[name], "FALSE")
                for name, value in {"MaxHead": "3", "MaxProduces": "3", "MaxTime": "2", "U": "2", "RefWindow": "1", "AncestryBudget": "1", "BlobCapacity": str(capacity), "ResourceProfile": '"Variable"', "Prefix": '"TwoJobs"', "Witness": '"None"'}.items():
                    self.assertEqual(values[name], value)
                for audit in ("AsyncSetupExact", "AsyncOriginsExact", "AsyncCompleteEnabled", "AsyncLandEnabled", "AsyncActionEffects", "ActualLandingParentAndSuffix", "OrdinaryFinalizationsCorrect"):
                    self.assertRegex(text, rf"(?m)^\s+{audit}$")

    def test_reachability_uses_exact_separate_named_violations(self):
        expected = {f"cap{cap}-witness-{kind}": invariant for cap in (1, 2) for kind, invariant in WITNESSES.items()}
        expected.update({"cap1-witness-budget": "AsyncBudgetNotReached", "cap2-witness-resume": "AsyncResumeNotReached"})
        for stem, invariant in expected.items():
            with self.subTest(stem=stem):
                text = (PRODUCT / (stem + ".cfg")).read_text()
                self.assertEqual(CHECK.parse_expectation(text), invariant)
                self.assertRegex(text, rf"(?m)^\s+{invariant}$")
                self.assertNotEqual(constants(text)["Witness"], '"None"')

    def test_focused_source_controls_are_positive_and_exact(self):
        for stem, invariant in (("cap1-complete-audit", "AsyncCompleteEnabled"), ("cap1-budget-audit", "AsyncLandEnabled")):
            text = (PRODUCT / (stem + ".cfg")).read_text()
            self.assertEqual(CHECK.parse_expectation(text), "PASS")
            invariants = text.split("INVARIANTS\n", 1)[1].split()
            self.assertEqual(invariants, [invariant])

    def test_source_controls_bind_the_unchanged_real_operational_guards(self):
        source = (ROOT / "EtnaProvingProgress.tla").read_bytes()
        self.assertEqual(hashlib.sha256(source).hexdigest(),
                         "4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c0f095aa75016fa0105")
        self.assertEqual(source.count(b"/\\ r.jobs[target].present /\\ r.jobs[source].present /\\ r.privateHistory /\\ r.available[b]"), 1)
        self.assertEqual(source.count(b"/\\ Len(r.published[j])<=BlobCapacity"), 1)

    def test_every_profile_has_one_valid_local_module_and_expectation(self):
        profiles = list(PRODUCT.glob("*.cfg"))
        self.assertEqual(len(profiles), 14)
        for profile in profiles:
            text = profile.read_text()
            CHECK.parse_expectation(text)
            self.assertEqual(CHECK.resolve_module(text, ROOT).name, "EtnaProvingAsyncProduct.tla")


if __name__ == "__main__":
    unittest.main()
