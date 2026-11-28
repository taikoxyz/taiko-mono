"""Check the boundaries between a modeled call, its trace and its source claim."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

CONF = Path(__file__).resolve().parents[1] / "conformance"
sys.path.insert(0, str(CONF))
import proving_recovery as proving
import registry_vacancy_observer as registry
import run_comet_apphash_native as native
import timestamp_recovery as timestamp


class ProductEvidence(unittest.TestCase):
    def test_native_preflight_rejects_replaced_public_projection(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            pins = json.loads((native.PROFILE / "pins.json").read_bytes())
            names = set(pins["inputsSha256"]) | {
                "comet_handover/apphash/pins.json", "manifests/comet.json",
                "comet_signed/public-votes.json"}
            for name in names:
                dest = root / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(CONF / name, dest)
            projection = root / "comet_signed/public-votes.json"
            projection.write_bytes(projection.read_bytes() + b"\n")
            for doc in native.CURRENT.DOCUMENT_PATHS:
                path = root / doc
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"unclassified workspace")
            output = root / "output"
            argv = [v for n in ("source", "go-root", "module-cache", "build-cache",
                                "build-lock", "workspace-root") for v in ("--" + n, str(root))]
            argv += ["--output", str(output), "--expected-cache-identity", "unused",
                     "--expected-lock-identity", "unused"]
            # Source classification/layout/stock source and native execution must
            # all be downstream of admission, with no source tree staged yet.
            with patch.object(native, "ROOT", root), patch.object(native, "PROFILE", root / "comet_handover/apphash"):
                with self.assertRaisesRegex(ValueError, "public-votes.json"):
                    native.main(argv)
            self.assertFalse(output.exists())

    def test_live_frame_consumes_each_unique_assignment(self):
        sample = "State 1: <Initial predicate>\n/\\ bad = FALSE\n/\\ milestone = 0\n/\\ s = <<>>\n"
        self.assertEqual(proving.states(sample), [()])
        for changed in (sample.replace("/\\ bad", "/\\ bad = FALSE\n/\\ bad"),
                        sample.replace("0\n", "0 1\n"), sample + "extra\n"):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                proving.states(changed)

    def test_native_set_and_function_preserve_value_types(self):
        self.assertEqual(proving.Reader("(1 :> {0, 1, 2})").value(), (frozenset({0, 1, 2}),))
        for value in ("(TRUE :> {0, 1, 2})", "{0, 1, TRUE, 2}", "{1, 1}"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                proving.Reader(value).value()

    def test_reset_replay_requires_stored_authorization(self):
        limits = timestamp.LIMITS["reset-safety"]
        pre = dict(timestamp.initial(limits), auth=(0, 0, 0, 108, 1))
        fresh = (0, 0, 0, 109, 1)
        # The contract accepts this independently supplied authorization.
        self.assertTrue(timestamp.can(pre, 5, (fresh, True), limits))
        post = timestamp.after(pre, 5, (fresh, True))
        self.assertTrue(timestamp.same(post, timestamp.after(pre, 5, (pre["auth"], True))))
        checker = getattr(timestamp, "check_offer", None)
        self.assertIsNotNone(checker, "missing profile offer validation")
        checker("reset-safety", pre, 5, (pre["auth"], True))
        for k, args in ((5, (fresh, True)), (5, (pre["auth"], False)), (6, ()),
                        (3, (1, 109)), (2, (104, True)), (2, (103, 1))):
            with self.subTest(k=k, args=args), self.assertRaises(ValueError):
                checker("reset-safety", pre, k, args)

    def test_refusal_fault_matches_all_registry_fields(self):
        pre = registry.initial_state()
        for key in (0, 1):
            ok, pre = registry.expected_transition(pre, dict(name="Register", key=key, actor=1, amount=3))
            self.assertTrue(ok)
        last = dict(accepted=False, call=dict(kind="Register", key=2, amount=3, actor=1))
        faulted = deepcopy(pre)
        faulted["nextId"] = 3
        faulted["keys"][2] = dict(registered=True, bond=2)
        for field in ("held", "deposited"):
            faulted["cash"][field] += 3
        registry._fault_shape("refusal", pre, last, faulted, pre, False)
        for path, wrong in ((("covered",), 1), (("bonds", 0, "owner"), 2),
                            (("keys", 2, "bond"), 1), (("cash", "deposited"), 6)):
            actual = deepcopy(faulted)
            node = actual
            for key in path[:-1]:
                node = node[key]
            node[path[-1]] = wrong
            with self.subTest(path=path), self.assertRaises(ValueError):
                registry._fault_shape("refusal", pre, last, actual, pre, False)

    def test_overlap_milestone_tracks_the_first_suffix_only_publication(self):
        statement = (141,)
        job = dict(cuts=((6, 6, 0, 0), (7, 7, 207, 1), (8, 8, 208, 2)),
                   data=(7, 8), statement=statement)
        pre = dict(included=7, jobs=(job, ()), proofs=((statement, statement), ((), ())))
        events = [("publish", 0, True), ("publish", 0, False), ("publish", 0, True)]
        frames = [pre] * (len(events)+1)
        proving.check_milestones(frames, events, [0, 0, 3, 3], "two-old-overlap")
        for wrong in ([0, 0, 0, 0], [0, 3, 3, 3], [0, 0, 3, 0], [3, 0, 3, 3]):
            with self.subTest(wrong=wrong), self.assertRaises(ValueError):
                proving.check_milestones(frames, events, wrong, "two-old-overlap")

    def test_claim_rejects_swapped_scope_and_unknown_documents(self):
        with TemporaryDirectory() as directory:
            workspace = Path(directory)
            for doc in native.CURRENT.DOCUMENT_PATHS:
                path = workspace / doc
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"unreviewed revision")
            for module, case, swapped in ((proving, "unit", "timestamp-stop"),
                                          (timestamp, "terminal", "arbitrary-height-landing")):
                with self.subTest(case=case):
                    with self.assertRaisesRegex(ValueError, "expected claim"):
                        module.current_receipt(workspace, case, b"", expected_claim=swapped)
                    with self.assertRaisesRegex(ValueError, "workspace documents"):
                        module.current_receipt(workspace, case, b"")

    def test_observed_produce_anchor_and_finalization_index_are_typed(self):
        pre = proving.initial(1)
        limits = dict(capacity=1, max_time=2, max_produces=1)
        anchor = pre["parentAnchor"]
        post = dict(pre, head=7, producedCount=1, canonical=(pre["canonical"][0], (7, 7, 207, 1)))
        self.assertEqual(proving.replay([pre, post], **limits)[0], ("produce", 0, 7, anchor))
        for wrong in ((False, *anchor[1:]), (*anchor[:3], (6, 6, False, 0))):
            with self.subTest(wrong=wrong), self.assertRaises(ValueError):
                proving.replay([pre, dict(post, parentAnchor=wrong)], **limits)
        ticks = [pre, dict(pre, now=1), dict(pre, now=2)]
        self.assertEqual(proving.replay(ticks + [dict(ticks[-1], finalizedBlock=1)], **limits)[-1],
                         ("finalize", 6, 1))
        with self.assertRaises(ValueError):
            proving.replay(ticks + [dict(ticks[-1], finalizedBlock=True)], **limits)
