"""The safety quotient preserves the timestamp product's actual observations."""
import hashlib
import importlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from test_current_spec_boundaries import CURRENT, DOCS, WORKSPACE_SPEC, document_identity

ROOT = Path(__file__).resolve().parents[3]
FORMAL = Path("formal/etna")
PRODUCT = FORMAL / "EtnaTimestampRecoveryProduct.tla"
SCHEDULE = FORMAL / "EtnaTimestampSchedule.tla"
WRAPPER = FORMAL / "EtnaTimestampSafety.tla"
CONFIG = FORMAL / "products/timestamp-safety/reset-safety.cfg"
SMALL_CONFIG = FORMAL / "products/timestamp-safety/small-safety.cfg"
ORIGINAL_CONFIG = FORMAL / "products/timestamp-recovery/reset-safety.cfg"
ORIGINAL_SMALL_CONFIG = FORMAL / "products/timestamp-recovery/small-safety.cfg"
ORACLE = FORMAL / "conformance/timestamp_recovery.py"
PARSER = FORMAL / "conformance/proving_recovery.py"
ARGV = ("/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
        "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
        "-deadlock", "-metadir", "/tmp/etna-out/states", "-config",
        "reset-safety.cfg", "EtnaTimestampSafety.tla")

# A minimal completion transcript for testing the receipt parser.
COMPLETE = b"""TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
Parsing file /tmp/etna-source/model/EtnaTimestampSafety.tla
Parsing file /tmp/etna-source/model/EtnaTimestampRecoveryProduct.tla
Parsing file /tmp/etna-source/model/EtnaTimestampSchedule.tla
Semantic processing of module EtnaTimestampSafety
Starting... (2026-11-19 11:56:32)
Computing initial states...
Finished computing initial states: 1 distinct state generated at 2026-11-19 11:56:32.
Model checking completed. No error has been found.
33 states generated, 14 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 5.
The average outdegree of the complete state graph is 1 (minimum is 0, the maximum 3 and the 95th percentile is 3).
Finished in 00s at (2026-11-19 11:56:33)
"""

sys.path.insert(0, str(ROOT / FORMAL / "conformance"))


class TimestampProjection(unittest.TestCase):
    def projection(self):
        self.assertTrue((ROOT / FORMAL / "conformance/timestamp_projection.py").is_file(),
                        "timestamp projection source and receipt are missing")
        return importlib.import_module("timestamp_projection")

    def source(self):
        projection = self.projection()
        return projection.audit_projection_source, (ROOT / PRODUCT).read_bytes(), (ROOT / WRAPPER).read_bytes()

    def checkout(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        root = Path(scratch.name)
        for name in (PRODUCT, SCHEDULE, WRAPPER, CONFIG, ORIGINAL_CONFIG, ORIGINAL_SMALL_CONFIG,
                     ORACLE, PARSER, *map(Path, DOCS)):
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        return root

    def staged_model(self, checkout):
        staged = checkout / "staged"
        staged.mkdir()
        for path in (PRODUCT, SCHEDULE, WRAPPER, CONFIG, SMALL_CONFIG):
            shutil.copyfile(ROOT / path, staged / path.name)
        return staged

    def execution(self, staged, *, case="reset-safety", raw=COMPLETE, **changes):
        config = case + ".cfg"
        inputs = {name: hashlib.sha256((staged / name).read_bytes()).hexdigest()
                  for name in (config, PRODUCT.name, WRAPPER.name, SCHEDULE.name)}
        record = {"schema": "etna-timestamp-projection-execution-1", "case": case,
                  "argv": (*ARGV[:-2], config, ARGV[-1]), "cwd": "/tmp/etna-source/model",
                  "returncode": 0, "timedOut": False, "rawSha256": hashlib.sha256(raw).hexdigest(),
                  "inputSha256": inputs}
        record.update(changes)
        return json.dumps(record).encode()

    def receipt(self, emit, checkout, staged, *, case="reset-safety", raw=COMPLETE,
                execution=None, expected_claim=None, **changes):
        execution = self.execution(staged, case=case, raw=raw, **changes) if execution is None else execution
        return emit(checkout, case, raw, execution=execution, staged_model=staged, expected_claim=expected_claim)

    def require_current(self, emit, checkout, staged):
        current = WORKSPACE_SPEC[document_identity((checkout / DOCS[0]).read_bytes())["sha256"]] == CURRENT
        if not current:
            with self.assertRaisesRegex(ValueError, "requires the current reviewed workspace"):
                self.receipt(emit, checkout, staged)
        return current

    def test_reviewed_projection_retains_sticky_failure(self):
        audit, product, wrapper = self.source()
        evidence = audit(product, wrapper)
        self.assertEqual(evidence["view"], ["s", "bad"])
        self.assertEqual(evidence["productSha256"], hashlib.sha256(product).hexdigest())
        self.assertEqual(evidence["wrapperSha256"], hashlib.sha256(wrapper).hexdigest())
        missing_bad = wrapper.replace(b"<<s,bad>>", b"<<s>>")
        self.assertNotEqual(wrapper, missing_bad)
        with self.assertRaises(ValueError):
            audit(product, missing_bad)

    def test_old_seen_cannot_become_an_actual_call_guard(self):
        audit, product, wrapper = self.source()
        changed = product.replace(b" k=3 -> TRUE\n", b" k=3 -> ~seen.recovered\n", 1)
        self.assertNotEqual(product, changed)
        with self.assertRaises(ValueError):
            audit(changed, wrapper)

    def test_old_last_cannot_become_an_actual_call_guard(self):
        audit, product, wrapper = self.source()
        changed = product.replace(b" k=3 -> TRUE\n", b" k=3 -> last[1] = 0\n", 1)
        self.assertNotEqual(product, changed)
        with self.assertRaises(ValueError):
            audit(changed, wrapper)

    def test_dispatch_requires_the_whole_actual_primed_receipt(self):
        audit, product, wrapper = self.source()
        actual = b"Next /\\ last'= <<k,a,ok,e>> /\\ s'=r"
        for replacement in (b"Next /\\ s'=r", b"Next /\\ SubSeq(last',1,3)= <<k,a,ok>> /\\ s'=r"):
            changed = product.replace(actual, replacement)
            self.assertNotEqual(product, changed)
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                audit(changed, wrapper)

    def test_known_sibling_claim_cannot_relabel_actual_producer(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if self.require_current(emit, checkout, staged):
            execution = self.execution(staged)
            receipt = self.receipt(emit, checkout, staged, execution=execution)
            self.assertEqual(receipt["claim"]["claimId"], "timestamp-projection")
            self.assertEqual(receipt["rawSha256"], hashlib.sha256(COMPLETE).hexdigest())
            self.assertEqual(receipt["executionSha256"], hashlib.sha256(execution).hexdigest())
            self.assertEqual(receipt["configSha256"], hashlib.sha256((staged / CONFIG.name).read_bytes()).hexdigest())
        with self.assertRaisesRegex(ValueError, "expected claim differs"):
            self.receipt(emit, checkout, staged, expected_claim="repeated-recovery")

    def test_receipt_requires_completed_projected_safety(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if not self.require_current(emit, checkout, staged):
            return
        for raw, code in (
            (COMPLETE, 12),
            (COMPLETE, 124),
            (COMPLETE, False),
            (COMPLETE, 0.0),
            (COMPLETE.replace(b"0 states left", b"1 states left"), 0),
            (COMPLETE.rsplit(b"Finished in ", 1)[0], 0),
            (COMPLETE.replace(b"Parsing file /tmp/etna-source/model/EtnaTimestampSafety.tla\n", b""), 0),
            (COMPLETE.replace(b"Model checking completed.", b"Error: foo\nModel checking completed."), 0),
            (COMPLETE + b"Error: late diagnostic\n", 0),
        ):
            with self.subTest(code=code, raw=raw), self.assertRaises(ValueError):
                self.receipt(emit, checkout, staged, raw=raw, returncode=code)
        with self.assertRaises(ValueError):
            self.receipt(emit, checkout, staged, case="structural", execution=self.execution(staged))
        for timed_out in (True, 0):
            with self.subTest(timed_out=timed_out), self.assertRaises(ValueError):
                self.receipt(emit, checkout, staged, timedOut=timed_out)

    def test_receipt_rejects_changed_config_and_schedule_with_same_raw(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if not self.require_current(emit, checkout, staged):
            return
        execution = self.execution(staged)
        receipt = self.receipt(emit, checkout, staged, execution=execution)
        for target in (staged / CONFIG.name, staged / SCHEDULE.name, checkout / ORIGINAL_CONFIG,
                       checkout / ORACLE, checkout / PARSER):
            original = target.read_bytes()
            target.write_bytes(original + b"\n")
            try:
                with self.subTest(path=target.name), self.assertRaises(ValueError):
                    self.receipt(emit, checkout, staged, execution=execution)
            finally:
                target.write_bytes(original)
        self.assertEqual(self.receipt(emit, checkout, staged, execution=execution), receipt)

    def test_same_raw_cannot_switch_the_case_or_effective_native_config(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if not self.require_current(emit, checkout, staged):
            return
        execution = self.execution(staged)
        self.receipt(emit, checkout, staged, execution=execution)
        with self.assertRaises(ValueError):
            self.receipt(emit, checkout, staged, case="small-safety", execution=execution)
        with self.assertRaises(ValueError):
            self.receipt(emit, checkout, staged, argv=(*ARGV[:-2], SMALL_CONFIG.name, ARGV[-1]))
        (staged / CONFIG.name).write_bytes((staged / SMALL_CONFIG.name).read_bytes())
        with self.assertRaises(ValueError):
            self.receipt(emit, checkout, staged, execution=execution)
        with self.assertRaises(ValueError):
            self.receipt(emit, checkout, staged)

    def test_successful_sibling_raw_does_not_prove_selected_profile(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if not self.require_current(emit, checkout, staged):
            return
        selected_argv = (*ARGV[:-2], SMALL_CONFIG.name, ARGV[-1])
        selected_raw = COMPLETE.replace(b"33 states generated, 14", b"100 states generated, 27")
        self.assertNotEqual(selected_raw, COMPLETE)
        selected_run = self.execution(staged, case="small-safety", argv=selected_argv, raw=selected_raw)
        selected = self.receipt(emit, checkout, staged, case="small-safety", execution=selected_run, raw=selected_raw)
        self.assertEqual(selected["case"], "small-safety")
        with self.assertRaisesRegex(ValueError, "transcript differs from the captured execution"):
            self.receipt(emit, checkout, staged, case="small-safety", execution=selected_run, raw=COMPLETE)
        reset_run = self.execution(staged)
        with self.assertRaisesRegex(ValueError, "transcript differs from the captured execution"):
            self.receipt(emit, checkout, staged, execution=reset_run, raw=selected_raw)

    def test_modeled_projection_scope_does_not_claim_unoffered_rules_write(self):
        from current_spec import select_claim

        scope = select_claim(CURRENT, "boundary-products", "timestamp-projection")
        self.assertNotIn("START-10.1-5a", scope["ruleIds"])

    def test_closed_execution_record_rejects_metadata_and_wrong_native_paths(self):
        emit = self.projection().projection_receipt
        checkout = self.checkout()
        staged = self.staged_model(checkout)
        if not self.require_current(emit, checkout, staged):
            return
        execution = self.execution(staged)
        parsed = json.loads(execution)
        wrong_source = parsed["inputSha256"] | {SCHEDULE.name: "0" * 64}
        missing = {key: value for key, value in parsed.items() if key != "case"}
        for record in (
            self.execution(staged, schema="unknown"),
            self.execution(staged, extra=True),
            self.execution(staged, cwd="/tmp/other-model"),
            self.execution(staged, inputSha256=wrong_source),
            json.dumps(missing).encode(),
            execution.replace(b'"argv":', b'"case": "reset-safety", "argv":', 1),
            execution.replace(b'"EtnaTimestampSchedule.tla":', b'"reset-safety.cfg": "dup", "EtnaTimestampSchedule.tla":', 1),
        ):
            with self.subTest(record=record), self.assertRaises(ValueError):
                self.receipt(emit, checkout, staged, execution=record)


if __name__ == "__main__":
    unittest.main()
