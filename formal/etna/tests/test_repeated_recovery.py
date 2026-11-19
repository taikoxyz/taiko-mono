"""Raw repeated-recovery edges with literal authority, origin and checkpoint fixtures."""
from copy import deepcopy
import hashlib
import importlib
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
CONFORMANCE = ROOT / "formal/etna/conformance"
sys.path.insert(0, str(CONFORMANCE))

PENDING = (0, 1, 1397, 1394)
PRESERVED = (0, 1, 1397, 0)
REPLACED = (2, 2, 0, 0)
GENESIS_CUT = (0, 100, 0, 0)
C6 = (6, 106, 206, 4)
C7 = (7, 307, 407, 4)


def origin(g, h, number, time, rule):
    return dict(generation=g, height=h, number=number, time=time, rule=rule, domain=100 + g)


def bootstrap(record, cut, root):
    return dict(**record, initialHeight=cut[0] + 1, el=cut[1], stateRoot=root, fi=cut[3])


def authorization(g, nonce, rules):
    return dict(generation=g, checkpoint=6, nonce=nonce, validUntil=107,
                rules=rules, owner=True, exclusions=(), fiToClear=())


def block(g, cut, bft, time, anchor, anchor_cut, schedule, rule, previous):
    return dict(generation=g, domain=100 + g, cut=cut, stateRoot=400 + cut[1],
                bftTime=bft, elTime=time, anchor=anchor, anchorCut=anchor_cut,
                schedule=schedule, rule=rule, lastBlockID=previous,
                lastCommit=() if previous == () else (g, previous))


def landing(g, parent, number, reference, snapshot, cut, root):
    return dict(generation=g, parentHeight=parent, number=number, reference=reference,
                activeSnapshot=snapshot,
                cut=cut, stateRoot=root)


def captured(g, reference, snapshot, cut, root):
    data = (cut[1],)
    return dict(generation=g, reference=reference, dependency=snapshot, cuts=(C6, cut),
                data=data,
                statement=(1, 1, 167000, 4369, 8738, g, 6, 106, 206, 333, 7,
                           cut[1], cut[2], root, reference, 500 + reference,
                           data, 4, 4, snapshot, (2, g, 6, 7, ())))


OLD_NONCE = authorization(0, 0, 0)
R1_AUTH = authorization(0, 1, 0)
R2_AUTH = authorization(1, 2, 2)
O0 = origin(0, 0, 25, 94, 0)
O1 = origin(1, 6, 32, 101, 0)
O2 = origin(2, 6, 35, 104, 2)
L6 = landing(0, 0, 31, 30, 24, C6, 506)
L7 = landing(2, 6, 36, 35, 35, C7, 707)
B1 = block(1, (7, 207, 307, 4), 101, 101, 32, C6, PRESERVED, 0, ())
B2 = block(2, C7, 104, 104, 35, C6, REPLACED, 2, ())
B3 = block(2, (8, 308, 408, 4), 105, 105, 36, C7, REPLACED, 2, 407)
J1 = captured(1, 32, 32, B1["cut"], 607)
J2 = captured(2, 35, 35, C7, 707)
ACTIONS = ("advance", "finalize", "invalidate", "recover", "observe", "produce", "capture", "land")


def sample():
    prefix = tuple(
        block(0, (h, 100 + h, 200 + h, min(h, 4)), 93 + h, 94 + h, 24 + h,
              GENESIS_CUT, (0, 0, 0, 0) if h <= 4 else PENDING, 0,
              () if h == 1 else 199 + h)
        for h in range(1, 7)
    )
    state = dict(generation=0, nonce=0, c=6, head=6, fiHead=4, activeSnapshot=24,
                 l1=31, finalized=31, produces=0, schedule=PENDING, origins=(O0,),
                 authBank=(OLD_NONCE, R1_AUTH, R2_AUTH), canonical=prefix, records=(L6,),
                 bootstrap=bootstrap(O0, GENESIS_CUT, 500), job=(),
                 archivedBlocks=(), archivedJob=())
    stages = [(state, ())]

    def edge(kind, args, **changes):
        accepted = changes.pop("accepted", True)
        next_state = dict(stages[-1][0], **changes)
        receipt = dict(kind=ACTIONS.index(kind) + 1, args=args, accepted=accepted)
        stages.append((next_state, receipt))

    edge("advance", (), l1=32)
    edge("invalidate", (0,), nonce=1)
    edge("recover", (1, OLD_NONCE), accepted=False)
    edge("recover", (2, R1_AUTH), generation=1, nonce=2, schedule=PRESERVED,
         origins=(O0, O1), bootstrap=())
    edge("recover", (2, R1_AUTH), accepted=False)
    edge("advance", (), l1=33)
    edge("finalize", (32,), finalized=32)
    edge("observe", (32,), bootstrap=bootstrap(O1, C6, 506))
    edge("produce", (32,), produces=1, head=7, canonical=prefix + (B1,))
    edge("capture", (6, 7, 32), job=J1)
    edge("advance", (), l1=34)
    edge("advance", (), l1=35)
    edge("recover", (3, R2_AUTH), generation=2, nonce=3, head=6, schedule=REPLACED,
         origins=(O0, O1, O2), canonical=prefix, bootstrap=(), job=(),
         archivedBlocks=(B1,), archivedJob=J1)
    edge("observe", (32,), accepted=False)
    edge("observe", (35,), accepted=False)
    edge("land", (2, J1), accepted=False)
    edge("advance", (), l1=36)
    edge("finalize", (35,), finalized=35)
    edge("observe", (35,), bootstrap=bootstrap(O2, C6, 506))
    edge("produce", (35,), produces=2, head=7, canonical=prefix + (B2,))
    edge("capture", (6, 7, 35), job=J2)
    edge("land", (1, J2), c=7, activeSnapshot=35, records=(L6, L7))
    edge("advance", (), l1=37)
    edge("finalize", (36,), finalized=36)
    edge("produce", (36,), produces=3, head=8, canonical=prefix + (B2, B3))
    return deepcopy(stages)


def tlc(value):
    if type(value) is bool:
        return "TRUE" if value else "FALSE"
    if type(value) is int:
        return str(value)
    if type(value) is dict:
        return "[" + ", ".join(f"{name} |-> {tlc(term)}" for name, term in value.items()) + "]"
    if type(value) is tuple:
        return "<<" + ", ".join(map(tlc, value)) + ">>"
    raise TypeError(type(value))


def raw(stages):
    return "".join(f"State {i}: <fixture>\n/\\ s = {tlc(state)}\n/\\ receipt = {tlc(receipt)}\n"
                   for i, (state, receipt) in enumerate(stages, 1))


class RepeatedRecovery(unittest.TestCase):
    def audit(self, trace, case="progress"):
        self.assertTrue((CONFORMANCE / "repeated_recovery.py").is_file(),
                        "repeated-recovery trajectory auditor is missing")
        return importlib.import_module("repeated_recovery").audit(trace, case)

    def test_live_second_generation_uses_own_finalized_landing(self):
        stages = sample()
        results = self.audit(raw(stages))
        self.assertEqual(results[-1], dict(kind="produce", args=(36,), accepted=True,
                                           pre=stages[-2][0], post=stages[-1][0]))
        self.assertEqual(results[-1]["post"]["canonical"][-1]["anchorCut"], C7)

    def test_same_generation_stale_nonce_is_a_real_refused_attempt(self):
        stages = sample()
        stages[3][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "recover.*decision"):
            self.audit(raw(stages))

    def test_retained_old_generation_authorization_cannot_execute(self):
        stages = sample()
        stages[5][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "recover.*decision"):
            self.audit(raw(stages))

    def test_replacing_attempted_authorization_from_pre_is_rejected(self):
        stages = sample()
        stages[5][1]["args"] = (2, authorization(1, 2, 0))
        with self.assertRaisesRegex(ValueError, "external authorization bank"):
            self.audit(raw(stages))

    def test_r1_only_finality_cannot_bootstrap_generation_two(self):
        stages = sample()
        stages[14][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "observe.*decision"):
            self.audit(raw(stages))

    def test_r2_record_without_own_r_finality_cannot_bootstrap(self):
        stages = sample()
        stages[15][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "observe.*decision"):
            self.audit(raw(stages))

    def test_second_recovery_cannot_overwrite_first_origin(self):
        stages = sample()
        stages[13][0]["origins"] = (O0, O2, O2)
        with self.assertRaisesRegex(ValueError, "recover.*origins"):
            self.audit(raw(stages))

    def test_rules_zero_clears_stop_and_keeps_pending_rule(self):
        stages = sample()
        stages[4][0]["schedule"] = (0, 0, 0, 0)
        with self.assertRaisesRegex(ValueError, "recover.*schedule"):
            self.audit(raw(stages))

    def test_nonzero_rules_replace_active_pending_and_activation_time(self):
        stages = sample()
        stages[13][0]["schedule"] = (2, 2, 1397, 0)
        with self.assertRaisesRegex(ValueError, "recover.*schedule"):
            self.audit(raw(stages))

    def test_recovery_does_not_mutate_settled_cut_or_fi(self):
        for field, value in (("records", (dict(L6, cut=(6, 106, 206, 0)),)), ("fiHead", 0),
                             ("activeSnapshot", 35)):
            with self.subTest(field=field):
                stages = sample()
                stages[13][0][field] = value
                with self.assertRaisesRegex(ValueError, "recover.*" + field):
                    self.audit(raw(stages))

    def test_second_recovery_cannot_keep_g1_suffix_live(self):
        stages = sample()
        stages[13][0]["head"] = 7
        stages[13][0]["canonical"] = stages[12][0]["canonical"]
        with self.assertRaisesRegex(ValueError, "recover.*(head|canonical)"):
            self.audit(raw(stages))

    def test_recovery_rejects_integer_boolean_and_duplicate_tlc_fields(self):
        stages = sample()
        changed = raw(stages).replace("owner |-> TRUE", "owner |-> 1", 1)
        with self.assertRaisesRegex(ValueError, "Init.*authBank"):
            self.audit(changed)
        duplicate = raw(stages).replace("generation |-> 0, nonce", "generation |-> 0, generation |-> 0, nonce", 1)
        with self.assertRaisesRegex(ValueError, "duplicate record field"):
            self.audit(duplicate)

    def test_complete_prefix_without_own_landing_anchor_has_no_progress_receipt(self):
        with self.assertRaisesRegex(ValueError, "progress.*endpoint"):
            self.audit(raw(sample()[:-1]))

    def test_observer_rejects_missing_second_bootstrap_dispatch(self):
        stages = sample()[:20]
        stages[19] = (stages[18][0], dict(kind=5, args=(35,), accepted=False))
        with self.assertRaisesRegex(ValueError, "observe.*decision"):
            self.audit(raw(stages))

    def test_receipt_checks_native_case_and_current_source(self):
        self.audit(raw(sample()))
        recovery = importlib.import_module("repeated_recovery")
        scope = importlib.import_module("boundary_scope")
        with tempfile.TemporaryDirectory() as temp:
            staged = Path(temp)
            module, config = recovery.MODULE, "progress.cfg"
            formal = ROOT / "formal/etna"
            for name, source in ((module, formal / module),
                                 (config, formal / "products/repeated-recovery" / config)):
                (staged / name).write_bytes(source.read_bytes())
            native_cwd = Path("/tmp/etna-model")
            raw_bytes = (
                "TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)\n"
                f"Parsing file {native_cwd / module}\n"
                "Semantic processing of module EtnaRepeatedRecovery\n"
                "Error: Invariant NoProgress is violated.\n"
                "Error: The behavior up to this point is:\n"
                + raw(sample()) + "\n"
                "35 states generated, 29 distinct states found, 8 states left on queue.\n"
                "The depth of the complete state graph search is 26.\n"
                "Finished in 00s at (2000-01-01 00:00:00)\n").encode()
            record = dict(schema="etna-repeated-recovery-execution-1", case="progress",
                          argv=["/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
                                "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
                                "-deadlock", "-metadir", "/tmp/etna-out/states", "-config", config, module],
                          cwd=str(native_cwd), returncode=12, timedOut=False,
                          rawSha256=hashlib.sha256(raw_bytes).hexdigest(),
                          inputSha256={name: hashlib.sha256((staged / name).read_bytes()).hexdigest()
                                       for name in (module, config)})

            def consume(metadata=record, **kwargs):
                return recovery.current_receipt(ROOT, "progress", raw_bytes,
                                                execution=json.dumps(metadata).encode(),
                                                staged_model=staged, **kwargs)

            for change in (dict(case="smoke"), dict(returncode=0), dict(timedOut=0),
                           dict(rawSha256="bad"), dict(argv=record["argv"][:14] + ["smoke.cfg", module])):
                with self.subTest(change=change), self.assertRaises(ValueError):
                    consume(dict(record, **change))
            with self.assertRaisesRegex(ValueError, "expected claim differs"):
                consume(expected_claim="mixed-rule-landing")
            try:
                selected = scope.reviewed_boundary(ROOT, "repeated-recovery")
            except ValueError as error:
                self.assertIn("current reviewed workspace", str(error))
                with self.assertRaisesRegex(ValueError, "current reviewed workspace"):
                    consume()
            else:
                self.assertEqual(selected["claim"]["execution"], "NOT_EVALUATED")
                receipt = consume()
                self.assertEqual(receipt["outcome"], "NAMED_WITNESS_REPLAYED")
                self.assertEqual(receipt["transitions"], 25)
                self.assertEqual(receipt["claim"]["claimId"], "repeated-recovery")
                for name, index, other in (
                    ("java", 0, "/tmp/other-jre/bin/java"),
                    ("jar", 4, "/tmp/other-tools/tla2tools.jar"),
                    ("metadir", 12, "/tmp/other-output/states"),
                ):
                    changed = record["argv"].copy()
                    changed[index] = other
                    with self.subTest(path=name), self.assertRaises(ValueError):
                        consume(dict(record, argv=changed))
                with self.assertRaises(ValueError):
                    consume(dict(record, cwd=str(staged)))
                (staged / config).write_bytes(b"changed")
                with self.assertRaisesRegex(ValueError, "captured execution"):
                    consume()

    def test_genesis_cutoff_precedes_start_write(self):
        initial = self.audit(raw(sample()))[0]["pre"]
        snapshot = initial["activeSnapshot"]
        self.assertEqual(snapshot, initial["records"][0]["activeSnapshot"])
        self.assertLess(snapshot, initial["origins"][0]["number"],
                        "committee-0 cutoff must precede the initialization and start block")

    def test_anchor_age_meets_the_deployment_minimum(self):
        source = (ROOT / "formal/etna/EtnaRepeatedRecovery.tla").read_text()
        anchor_age = re.search(r"^MaxAnchorAge == (\d+)$", source, re.M)
        self.assertIsNotNone(anchor_age, "missing model anchor-age bound")
        self.assertGreaterEqual(int(anchor_age[1]), 1152, "anchor age must meet START-10-9")

    def test_initial_pending_schedule_has_the_required_lead(self):
        initial = self.audit(raw(sample()))[0]["pre"]
        _, _, activation, stop = initial["schedule"]
        for name, time in (("rulesTime", activation), ("stopTime", stop)):
            with self.subTest(field=name):
                self.assertGreaterEqual(time, 98 + 1296, "slot 293 write must allow the anchor-age lead")

    def test_r1_truncates_live_g0_suffix_without_archiving_it(self):
        stages = sample()
        block7 = block(0, (7, 1107, 1207, 4), 100, 101, 31, C6, PENDING, 0, 206)
        initial = stages[0][0]
        extra = (dict(initial, head=7, produces=1, canonical=initial["canonical"] + (block7,)),
                 dict(kind=6, args=(31,), accepted=True))
        after = [stages[0], extra]
        for i, (state, receipt) in enumerate(stages[1:10], 1):
            until_recover = dict(head=7, canonical=initial["canonical"] + (block7,)) if i < 4 else {}
            after.append((dict(state, produces=state["produces"] + 1, **until_recover), receipt))
        try:
            events = self.audit(raw(after), "smoke")
        except ValueError as error:
            self.fail(f"ordinary g0 successor and R1 live reset must replay: {error}")
        recovery = next(edge for edge in events if edge["kind"] == "recover" and edge["accepted"])
        self.assertEqual(recovery["pre"]["canonical"][-1], block7)
        self.assertEqual(recovery["post"]["head"], 6)
        self.assertEqual(recovery["post"]["canonical"], initial["canonical"])
        self.assertEqual(recovery["post"]["archivedBlocks"], ())

    def test_old_generation_alone_fails_with_matching_nonzero_nonce(self):
        stages = sample()
        r1 = dict(stages[4][0], nonce=1)
        prefix = stages[:2] + [
            (r1, dict(kind=4, args=(1, OLD_NONCE), accepted=True)),
            (r1, dict(kind=4, args=(2, R1_AUTH), accepted=False)),
        ]
        result = self.audit(raw(prefix), "old-generation")[-1]
        self.assertEqual(result["args"][1]["nonce"], result["pre"]["nonce"])
        self.assertNotEqual(result["args"][1]["generation"], result["pre"]["generation"])
        self.assertFalse(result["accepted"])

    def _assert_fatal_receipt_diagnostics(self, case):
        from unittest.mock import patch

        recovery = importlib.import_module("repeated_recovery")
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        staged = Path(scratch.name)
        formal = ROOT / "formal/etna"
        module, config = recovery.MODULE, case + ".cfg"
        for name, source in ((module, formal / module),
                             (config, formal / "products/repeated-recovery" / config)):
            (staged / name).write_bytes(source.read_bytes())
        named = case == "progress"
        text = (recovery.TLC_BANNER + "\nParsing file /tmp/etna-model/" + module + "\n"
                "Semantic processing of module EtnaRepeatedRecovery\n")
        text += ("Error: Invariant NoProgress is violated.\n"
                 "Error: The behavior up to this point is:\n" + raw(sample())) if named else (
                 "Model checking completed. No error has been found.\n")
        original = (text + "100 states generated, 50 distinct states found, 0 states left on queue.\n"
                    "The depth of the complete state graph search is 40.\n"
                    "Finished in 00s at (2000-01-01 00:00:00)\n").encode()
        record = dict(schema="etna-repeated-recovery-execution-1", case=case,
                      argv=["/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
                            "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
                            "-deadlock", "-metadir", "/tmp/etna-out/states", "-config", config, module],
                      cwd="/tmp/etna-model", returncode=12 if named else 0, timedOut=False,
                      rawSha256=hashlib.sha256(original).hexdigest(),
                      inputSha256={name: hashlib.sha256((staged / name).read_bytes()).hexdigest()
                                   for name in (module, config)})

        def consume(body):
            metadata = dict(record, rawSha256=hashlib.sha256(body).hexdigest())
            return recovery.current_receipt(ROOT, case, body, execution=json.dumps(metadata).encode(),
                                            staged_model=staged)

        diagnostics = (
            b"java.lang.Exception: parser fixture\n",
            b"java.lang.Error: parser fixture\n",
            b'Exception in thread "main" java.lang.IllegalStateException: parser fixture\n',
            b"java.lang.OutOfMemoryError: parser fixture\n",
            b"\tat tlc2.tool.fixture.run(Fixture.java:1)\n",
            b"panic: parser fixture\n",
            b"Traceback (most recent call last):\n",
            b"FATAL: parser fixture\n",
            b"# A fatal error has been detected by the Java Runtime Environment:\n",
        )
        # Parser fixture only: stub final scope classification, not actual
        # capture/raw/status/source/argv checks. Acceptance is not native evidence.
        with patch.object(recovery, "reviewed_boundary", return_value={}):
            for diagnostic in diagnostics:
                with self.subTest(diagnostic=diagnostic):
                    healthy = consume(original)
                    self.assertEqual(healthy["outcome"],
                                     "NAMED_WITNESS_REPLAYED" if named else "FINITE_SAFETY_EXHAUSTED")
                    poisoned = original.replace(b"\n", b"\n" + diagnostic, 1)
                    with self.assertRaisesRegex(ValueError, "fatal native diagnostic"):
                        consume(poisoned)

    def test_fatal_diagnostics_are_refused_at_safety_receipt(self):
        self._assert_fatal_receipt_diagnostics("safety")

    def test_fatal_diagnostics_are_refused_at_named_receipt(self):
        self._assert_fatal_receipt_diagnostics("progress")
