"""Static opt-in profile contracts; these checks do not prove graph behavior."""
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("signer_async_check", ROOT / "check.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
PRODUCT = ROOT / "products/signer-async"
GUARDS = {"PersistBeforeExpose", "PreserveHRSOnCrash", "PreserveGenerationFence",
          "ReconnectAfterTrust", "RejectConflicts", "EchoRequest"}
WITNESSES = {"retry": ("Retry", "AsyncRetryNotReached"),
             "value-conflict": ("ValueConflict", "AsyncValueConflictNotReached"),
             "nil-conflict": ("NilConflict", "AsyncNilConflictNotReached"),
             "computed-recovery": ("ComputedRecovery", "AsyncComputedRecoveryNotReached"),
             "persisted-recovery": ("PersistedRecovery", "AsyncPersistedRecoveryNotReached"),
             "uncertain": ("Uncertain", "AsyncUncertainNotReached")}
AUDITS = {"AsyncInitExact", "AsyncRequestEnabled", "AsyncOtherEnabled",
          "AsyncExactReuse", "AsyncActionEffects"}


def constants(text):
    return dict(re.findall(r'^\s*(\w+)\s*=\s*(\S+)\s*$', text, re.MULTILINE))


class SignerProfileTests(unittest.TestCase):
    def test_profiles_are_explicit_opt_in(self):
        self.assertTrue((ROOT / "EtnaSignerAsyncProduct.tla").is_file(), "missing signer free-graph wrapper")
        self.assertTrue(PRODUCT.is_dir(), "missing opt-in signer profiles")
        self.assertFalse(any("EtnaSignerAsyncProduct" in p.read_text() for p in (ROOT / "configs").glob("*.cfg")))

    def test_normal_selects_full_bounds_guards_and_independent_audits(self):
        path = PRODUCT / "normal.cfg"
        self.assertTrue(path.is_file(), "missing joint full-graph normal profile")
        text = path.read_text()
        self.assertEqual(CHECK.parse_expectation(text), "PASS")
        self.assertEqual(CHECK.parse_module(text), "EtnaSignerAsyncProduct")
        self.assertIn("SPECIFICATION AsyncSpec", text)
        values = constants(text)
        for guard in GUARDS:
            self.assertEqual(values[guard], "TRUE")
        self.assertEqual({k: values[k] for k in ("MaxSlot", "Payloads", "SignatureSalts", "Witness")},
                         {"MaxSlot": "2", "Payloads": '{"A","B","Nil"}', "SignatureSalts": "{0,1}", "Witness": '"None"'})
        selected = set(text.split("INVARIANTS\n", 1)[1].split())
        self.assertTrue(AUDITS <= selected, AUDITS - selected)
        self.assertTrue({"SignerTypeOK", "ExposureWasDurable", "ReturnedSlotUnique",
                         "DeliveredSlotUnique", "ReplayUsesRecordedSignature", "NoOldDomainExposure"} <= selected)

    def test_exact_separate_witness_classification(self):
        for stem, (selector, invariant) in WITNESSES.items():
            path = PRODUCT / f"witness-{stem}.cfg"
            self.assertTrue(path.is_file(), f"missing {stem} witness")
            text = path.read_text()
            self.assertEqual(CHECK.parse_expectation(text), invariant)
            self.assertEqual(constants(text)["Witness"], f'"{selector}"')
            self.assertEqual(text.split("INVARIANTS\n", 1)[1].split(), [invariant])

    def test_focused_controls_select_precise_positive_audits(self):
        for stem, invariant in (("reuse-audit", "AsyncExactReuse"), ("request-audit", "AsyncRequestEnabled")):
            path = PRODUCT / (stem + ".cfg")
            self.assertTrue(path.is_file(), f"missing focused {stem} control")
            text = path.read_text()
            self.assertEqual(CHECK.parse_expectation(text), "PASS")
            self.assertEqual(text.split("INVARIANTS\n", 1)[1].split(), [invariant])

    def test_every_profile_resolves_local_module_without_weakened_switches(self):
        profiles = list(PRODUCT.glob("*.cfg"))
        self.assertEqual({p.stem for p in profiles}, {"normal", "reuse-audit", "request-audit"} |
                         {"witness-" + name for name in WITNESSES})
        for path in profiles:
            text = path.read_text()
            CHECK.parse_expectation(text)
            self.assertEqual(CHECK.resolve_module(text, ROOT).name, "EtnaSignerAsyncProduct.tla")
            for guard in GUARDS:
                self.assertEqual(constants(text)[guard], "TRUE")
            self.assertNotRegex(text, r"(?m)^\s*(CONSTRAINT|ACTION_CONSTRAINT|SYMMETRY)\b")

    def test_effect_frame_covers_every_operational_variable(self):
        # A newly added operational field must not escape every action audit.
        source = (ROOT / "EtnaSignerCrash.tla").read_text()
        wrapper = (ROOT / "EtnaSignerAsyncProduct.tla").read_text()
        declared = set(re.findall(r"[A-Za-z][A-Za-z0-9_]*", source.split("VARIABLES", 1)[1].split("vars ==", 1)[0]))
        fields = set(re.findall(r"([A-Za-z][A-Za-z0-9_]*)\s*\|->", wrapper.split("LState ==", 1)[1].split("LInitial ==", 1)[0]))
        self.assertEqual(fields, declared)
        initial = set(re.findall(r"([A-Za-z][A-Za-z0-9_]*)\s*\|->", wrapper.split("LInitial ==", 1)[1].split("Offers ==", 1)[0]))
        self.assertEqual(initial, declared)

    def test_source_control_targets_original_actual_request_branch(self):
        source = (ROOT / "EtnaSignerCrash.tla").read_bytes()
        self.assertEqual(hashlib.sha256(source).hexdigest(), "c948786960d3dd5af381c653f3c0c28795291b19d3b96e660efa8825f6d93c4a")
        self.assertEqual(source.count(b"pending' = IF reuse' THEN durable[d]"), 1)
        self.assertEqual(source.count(b"(s > durable[d].slot \\/ p = durable[d].payload \\/ ~RejectConflicts)"), 1)


if __name__ == "__main__":
    unittest.main()
