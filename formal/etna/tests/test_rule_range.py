"""Literal current-rule range observations; fixtures are not native evidence."""
from copy import deepcopy
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

ZERO = (0, 0, 0, 0)
FIRST = (0, 1, 3600, 0)
SECOND = (1, 2, 5184, 0)
P = 6
ACTION = ("advance", "finalize", "schedule", "prefix", "prefix_land", "prepare",
          "admit", "upgrade", "capture", "prove", "publish", "land")
L1 = ((25, 300), (190, 2280), (191, 2292), (192, 2304), (288, 3456),
      (298, 3576), (299, 3588), (300, 3600), (324, 3888),
      (432, 5184), (433, 5196), (434, 5208))
CUTS = tuple((h, 100 + h, 0 if h == 0 else 200 + h, 0) for h in range(11))


def view(number, checkpoint, schedule):
    return dict(number=number, time=dict(L1)[number], hash=500 + number,
                root=900 + number, checkpoint=CUTS[checkpoint], schedule=schedule)


VIEWS = (view(190, 0, ZERO), view(192, 4, FIRST), view(288, 4, FIRST),
         view(300, 6, FIRST), view(432, 6, SECOND), view(433, 6, SECOND))


def block(height, parent_time, bft, timestamp, anchor, parent_anchor, carry, rule):
    return dict(generation=0, cut=CUTS[height], stateRoot=400 + height,
                parentTime=parent_time, bftTime=bft, elTime=timestamp,
                anchor=anchor, parentAnchor=parent_anchor, carry=carry,
                anchorRoot=900 + anchor, anchorHash=500 + anchor,
                rule=rule, first=height == 1, origin=25, originTime=300,
                lastBlockID=0 if height == 1 else 199 + height)


PREFIX = (block(1, 0, 300, 2280, 190, 25, True, 0),
          block(2, 2280, 2281, 2281, 190, 190, False, 0),
          block(3, 2281, 2301, 2301, 190, 190, False, 0),
          block(4, 2301, 2302, 2302, 190, 190, False, 0))
B5 = block(5, 2302, 3597, 3597, 192, 190, True, 0)
B6 = block(6, 3597, 3597, 3598, 192, 192, False, 0)
BLOCKS = (block(7, 3598, 3599, 3599, 288, 192, True, 0),
          block(8, 3599, 3600, 3600, 288, 288, False, 1),
          block(9, 3600, 3600, 3601, 300, 288, True, 1),
          block(10, 3601, 5184, 5184, 432, 300, True, 2))
ADJACENT = ((0, 1), (1, 2))
ENDPOINTS = ((0,), (2,))


def landing(height, number, reference):
    return dict(generation=0, cut=CUTS[height], number=number,
                reference=reference, referenceHash=500 + reference,
                stateRoot=400 + height, activeSnapshot=24)


def job():
    cuts, data = CUTS[6:11], tuple(b["cut"][1] for b in BLOCKS)
    # ABI statement projection is the existing 21-word adapter's observer data.
    # Ordered rules remain outside that ABI projection.
    statement = (1, 1, 167000, 4369, 8738, 0, 6, 106, 206, 333, 10, 110,
                 210, 410, 433, 933, data, 0, 0, 24,
                 (2, 0, 6, 10, CUTS[7:10]))
    return dict(generation=0, reference=433, referenceHash=933, dependency=24,
                cuts=cuts, data=data, statement=statement, rules=(0, 1, 1, 2),
                blocks=BLOCKS)


def sample():
    """Literal ordinary complete path; timestamps are not a scaled reduction."""
    state = dict(generation=0, c=4, head=4, fiHead=0, activeSnapshot=24,
                 l1=191, finalized=190, initialized=True, owner=True,
                 schedule=ZERO, history=((25, ZERO),), software=(0,),
                 canonical=PREFIX, records=(landing(4, 191, 190),),
                 views=(VIEWS[0],), pending=(), job=(), proofs=(), published=(),
                 aggregateAvailable=(True, True), zkFamilies=(2,))
    stages = [(state, ())]

    def edge(kind, args, accepted=True, **changes):
        current = dict(stages[-1][0], **changes)
        stages.append((current, dict(kind=ACTION.index(kind) + 1,
                                     args=args, accepted=accepted)))

    edge("advance", (192,), l1=192)
    edge("schedule", (1, 3600), schedule=FIRST, history=((25, ZERO), (192, FIRST)))
    edge("advance", (288,), l1=288)
    edge("finalize", (192,), finalized=192, views=VIEWS[:2])
    edge("advance", (298,), l1=298)
    edge("prefix", (B5,), head=5, canonical=PREFIX + (B5,))
    edge("prefix", (B6,), head=6, canonical=PREFIX + (B5, B6))
    edge("advance", (299,), l1=299)
    edge("prefix_land", (6, 298), c=6,
         records=(landing(4, 191, 190), landing(6, 299, 298)))
    edge("finalize", (288,), finalized=288, views=VIEWS[:3])
    edge("prepare", (BLOCKS[0],), pending=BLOCKS[0])
    canonical = PREFIX + (B5, B6, BLOCKS[0])
    edge("admit", (), head=7, canonical=canonical, pending=())
    edge("advance", (300,), l1=300)
    edge("prepare", (BLOCKS[1],), pending=BLOCKS[1])
    # Abstract deterministic unsupported-rule admission refusal, not an ABCI API.
    edge("admit", (), accepted=False)
    edge("upgrade", (1,), software=(0, 1))
    canonical += (BLOCKS[1],)
    edge("admit", (), head=8, canonical=canonical, pending=())
    edge("advance", (324,), l1=324)
    edge("schedule", (2, 5184), schedule=SECOND,
         history=((25, ZERO), (192, FIRST), (324, SECOND)))
    edge("finalize", (300,), finalized=300, views=VIEWS[:4])
    edge("prepare", (BLOCKS[2],), pending=BLOCKS[2])
    canonical += (BLOCKS[2],)
    edge("admit", (), head=9, canonical=canonical, pending=())
    edge("advance", (432,), l1=432)
    edge("advance", (433,), l1=433)
    edge("finalize", (432,), finalized=432, views=VIEWS[:5])
    edge("upgrade", (2,), software=(0, 1, 2))
    edge("prepare", (BLOCKS[3],), pending=BLOCKS[3])
    canonical += (BLOCKS[3],)
    edge("admit", (), head=10, canonical=canonical, pending=())
    edge("advance", (434,), l1=434)
    edge("finalize", (433,), finalized=433, views=VIEWS)
    captured = job()
    edge("capture", (6, 10, 433), job=captured)
    edge("prove", (1, ADJACENT), proofs=((1, ADJACENT, captured["statement"]),))
    edge("prove", (2, ADJACENT),
         proofs=((1, ADJACENT, captured["statement"]), (2, ADJACENT, captured["statement"])))
    edge("publish", (captured["data"],), published=captured["data"])
    edge("land", (captured,), c=10,
         records=(landing(4, 191, 190), landing(6, 299, 298), landing(10, 434, 433)))
    return deepcopy(stages)


def tlc(value):
    if type(value) is bool:
        return "TRUE" if value else "FALSE"
    if type(value) is int:
        return str(value)
    if type(value) is tuple:
        return "<<" + ", ".join(map(tlc, value)) + ">>"
    if type(value) is dict:
        return "[" + ", ".join(f"{key} |-> {tlc(term)}" for key, term in value.items()) + "]"
    raise TypeError(type(value))


def raw(stages):
    return "".join(f"State {index}: <private-parser-fixture>\n/\\ s = {tlc(state)}\n"
                   f"/\\ receipt = {tlc(receipt)}\n"
                   for index, (state, receipt) in enumerate(stages, 1))
class RuleRange(unittest.TestCase):
    def setUp(self):
        default = Path(__file__).resolve().parents[3] / "formal/etna/conformance"
        conformance = Path(os.environ.get("ETNA_RULE_RANGE_CONFORMANCE", default))
        source = conformance / "rule_range.py"
        self.assertTrue(source.is_file(), "Y03 audit/resolve API absent: rule_range.py")
        sys.path.insert(0, str(conformance))
        spec = importlib.util.spec_from_file_location("etna_rule_range_under_test", source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(getattr(module, "audit", None)), "Y03 audit API absent")
        self.assertTrue(callable(getattr(module, "resolve_blocks", None)), "Y03 resolve API absent")
        self.module = module

    def reject(self, mutate, pattern):
        stages = sample()
        mutate(stages)
        with self.assertRaisesRegex(ValueError, pattern):
            self.module.audit(raw(stages), "progress")

    def test_complete_original_range_lands(self):
        events = self.module.audit(raw(sample()), "progress")
        self.assertEqual(events[-1]["kind"], "land")
        self.assertEqual(events[-1]["post"]["c"], 10)
        self.assertEqual(events[-1]["pre"]["job"]["rules"], (0, 1, 1, 2))

    def test_resolve_each_own_historical_anchor(self):
        self.assertEqual(self.module.resolve_blocks(BLOCKS, VIEWS), (0, 1, 1, 2))

    def test_latest_slot_reinterpretation_is_rejected(self):
        views = tuple(dict(v, schedule=SECOND) for v in VIEWS)
        with self.assertRaisesRegex(ValueError, "rule|histor|schedule"):
            self.module.resolve_blocks(BLOCKS, views)

    def test_no_interior_anchor_omission(self):
        with self.assertRaisesRegex(ValueError, "anchor|view"):
            self.module.resolve_blocks(BLOCKS, tuple(v for v in VIEWS if v["number"] != 300))

    def test_anchor_timestamp_freshness(self):
        views = tuple(dict(v, time=2303) if v["number"] == 432 else v for v in VIEWS)
        with self.assertRaisesRegex(ValueError, "age|old|time|anchor"):
            self.module.resolve_blocks(BLOCKS, views)

    def test_literal_parent_plus_one(self):
        blocks = BLOCKS[:2] + (dict(BLOCKS[2], elTime=3600),) + BLOCKS[3:]
        with self.assertRaisesRegex(ValueError, "time|successor"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_second_block_must_inherit_witness(self):
        blocks = (BLOCKS[0], dict(BLOCKS[1], carry=True)) + BLOCKS[2:]
        with self.assertRaisesRegex(ValueError, "witness|carry|anchor"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_correlated_second_first_marker_cannot_turn_inheritance_into_carry(self):
        false_first = dict(BLOCKS[1], first=True, carry=True, originTime=3600)
        for blocks in (BLOCKS[:1] + (false_first,) + BLOCKS[2:], (false_first,) + BLOCKS[2:]):
            with self.subTest(start=blocks[0]["cut"][0]), self.assertRaises(ValueError):
                self.module.resolve_blocks(blocks, VIEWS)

    def test_fixed_generation_and_origin_cannot_shift_as_a_unit(self):
        for context in (dict(generation=1), dict(origin=26, originTime=312), dict(originTime=301)):
            blocks = tuple(dict(block, **context) for block in BLOCKS)
            with self.subTest(context=context), self.assertRaises(ValueError):
                self.module.resolve_blocks(blocks, VIEWS)

    def test_genesis_prefix_uses_only_the_selected_first_block_context(self):
        self.assertEqual(self.module.resolve_blocks(PREFIX, VIEWS), (0, 0, 0, 0))
        for change in (dict(first=False), dict(bftTime=301, originTime=301),
                       dict(parentAnchor=300), dict(lastBlockID=200)):
            blocks = (dict(PREFIX[0], **change),) + PREFIX[1:]
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.module.resolve_blocks(blocks, VIEWS)

    def test_independent_first_flags_do_not_relax_range_continuity(self):
        blocks = BLOCKS[:1] + (dict(BLOCKS[1], lastBlockID=206),) + BLOCKS[2:]
        with self.assertRaisesRegex(ValueError, "continuity"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_checkpoint_of_same_anchor_covers_both_blocks(self):
        views = tuple(dict(v, checkpoint=CUTS[3]) if v["number"] == 288 else v for v in VIEWS)
        with self.assertRaisesRegex(ValueError, "checkpoint|pressure|unsettled"):
            self.module.resolve_blocks(BLOCKS, views)

    def test_final_anchor_must_already_prove_parent_checkpoint(self):
        views = tuple(dict(v, checkpoint=CUTS[5]) if v["number"] == 432 else v for v in VIEWS)
        with self.assertRaisesRegex(ValueError, "checkpoint|pressure|unsettled"):
            self.module.resolve_blocks(BLOCKS, views)

    def test_bool_cannot_alias_rule_zero(self):
        blocks = (dict(BLOCKS[0], rule=False),) + BLOCKS[1:]
        with self.assertRaisesRegex(ValueError, "int|rule|type"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_pause_is_lossless_for_every_live_field(self):
        initial = sample()
        index = next(i for i, (_, r) in enumerate(initial) if r and r["kind"] == 7 and not r["accepted"])
        for field, value in initial[index][0].items():
            with self.subTest(field=field):
                stages = deepcopy(initial)
                replacement = (not value if type(value) is bool else value + 1
                               if type(value) is int else () if value else (1,))
                stages[index][0][field] = replacement
                with self.assertRaisesRegex(ValueError, "admit|state|frame|differs"):
                    self.module.audit(raw(stages), "progress")

    def test_anchor_header_root_must_match_own_view(self):
        blocks = BLOCKS[:2] + (dict(BLOCKS[2], anchorRoot=999),) + BLOCKS[3:]
        with self.assertRaisesRegex(ValueError, "root|anchor|view"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_anchor_header_hash_must_match_own_view(self):
        blocks = BLOCKS[:2] + (dict(BLOCKS[2], anchorHash=999),) + BLOCKS[3:]
        with self.assertRaisesRegex(ValueError, "hash|anchor|view"):
            self.module.resolve_blocks(blocks, VIEWS)

    def test_fresh_proposal_cannot_choose_older_finalized_anchor(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 6)
            changed = dict(BLOCKS[0], anchor=192, anchorHash=692, anchorRoot=1092, carry=False)
            stages[index][1]["args"] = (changed,)
            stages[index][0]["pending"] = changed
        self.reject(mutate, "prepare|anchor|final|arg")

    def test_aggregation_availability_is_not_image_union(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 10)
            stages[index][0]["aggregateAvailable"] = (False, True)
        self.reject(mutate, "aggregat|prove|state|frame")

    def test_scheduling_requires_actual_initialized_owner(self):
        def mutate(stages):
            stages[0][0]["initialized"] = False
        self.reject(mutate, "Init|initial|schedule")

    def test_second_write_promotes_previous_next(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 3 and r["args"] == (2, 5184))
            stages[index][0]["schedule"] = (0, 2, 5184, 0)
        self.reject(mutate, "schedule|promot|frame")

    def test_old_schedule_history_never_rewritten(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 3 and r["args"] == (2, 5184))
            stages[index][0]["history"] = ((25, (0, 0, 0, 0)), (192, SECOND), (324, SECOND))
        self.reject(mutate, "history|schedule|frame")

    def test_endpoint_capable_family_cannot_omit_interior_one(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 10)
            receipt = stages[index][1]
            receipt["args"] = (1, ENDPOINTS)
            statement = stages[index][0]["job"]["statement"]
            stages[index][0]["proofs"] = ((1, ENDPOINTS, statement),)
        self.reject(mutate, "family|interior|rule|prove|capabil")
        stages = sample()
        index = next(i for i, (_, receipt) in enumerate(stages)
                     if receipt and receipt["kind"] == 10)
        stages.insert(index, (deepcopy(stages[index - 1][0]),
                              dict(kind=10, args=(1, ENDPOINTS), accepted=False)))
        events = self.module.audit(raw(stages), "progress")
        self.assertTrue(any(event["kind"] == "prove" and not event["accepted"]
                            for event in events))

    def test_family_capability_union_is_not_complete_pair(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 10 and r["args"][0] == 2)
            statement = stages[index][0]["job"]["statement"]
            stages[index][0]["proofs"] = ((1, ENDPOINTS, statement), (2, ((1,),), statement))
        self.reject(mutate, "family|prove|proof|frame|rule")

    def test_reference_number_cannot_precede_last_anchor(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 9)
            stages[index][1]["args"] = (6, 10, 300)
        self.reject(mutate, "reference|capture|arg")

    def test_reference_hash_is_bound(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 9)
            stages[index][0]["job"]["referenceHash"] += 1
        self.reject(mutate, "reference|job|capture|frame")

    def test_full_ordered_blobs_cannot_be_suffix(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 11)
            stages[index][1]["args"] = ((109, 110),)
            stages[index][0]["published"] = (109, 110)
        self.reject(mutate, "publish|blob|range|arg")

    def test_three_interior_cuts_required(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 9)
            stages[index][0]["job"]["cuts"] = CUTS[6:8] + CUTS[9:11]
        self.reject(mutate, "cut|job|capture|frame")

    def test_no_new_abi_rule_word(self):
        def mutate(stages):
            index = next(i for i, (_, r) in enumerate(stages) if r and r["kind"] == 9)
            stages[index][0]["job"]["statement"] += ((0, 1, 1, 2),)
        self.reject(mutate, "statement|job|capture|frame")

    def test_trailing_raw_terms_rejected(self):
        with self.assertRaisesRegex(ValueError, "trailing|TLC|native|term"):
            self.module.audit(raw(sample()) + "UNPARSED", "progress")

    def _assert_fatal_receipt_diagnostics(self, case):
        from unittest.mock import patch

        root = Path(__file__).resolve().parents[3]
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        staged = Path(scratch.name)
        module, config = self.module.MODULE, case + ".cfg"
        formal = root / "formal/etna"
        for name, source in ((module, formal / module),
                             (config, formal / "products/rule-range" / config)):
            (staged / name).write_bytes(source.read_bytes())
        named = case == "progress"
        text = (self.module.TLC_BANNER + "\nParsing file /tmp/etna-model/" + module + "\n"
                "Semantic processing of module EtnaRuleRange\n")
        text += ("Error: Invariant NoProgress is violated.\n"
                 "Error: The behavior up to this point is:\n" + raw(sample())) if named else (
                 "Model checking completed. No error has been found.\n")
        original = (text + "100 states generated, 50 distinct states found, 0 states left on queue.\n"
                    "The depth of the complete state graph search is 40.\n"
                    "Finished in 00s at (2000-01-01 00:00:00)\n").encode()
        record = dict(schema="etna-rule-range-execution-1", case=case,
                      argv=["/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
                            "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
                            "-deadlock", "-metadir", "/tmp/etna-out/states", "-config", config, module],
                      cwd="/tmp/etna-model", returncode=12 if named else 0, timedOut=False,
                      rawSha256=hashlib.sha256(original).hexdigest(),
                      inputSha256={name: hashlib.sha256((staged / name).read_bytes()).hexdigest()
                                   for name in (module, config)})

        def consume(body):
            metadata = dict(record, rawSha256=hashlib.sha256(body).hexdigest())
            return self.module.current_receipt(root, case, body, execution=json.dumps(metadata).encode(),
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
        # Parser fixture only: final scope classification is stubbed; actual
        # raw/status/source/argv/audit paths run. No native evidence is produced.
        with patch.object(self.module, "reviewed_boundary", return_value={}):
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

    def test_initial_committee_profile_has_past_cutoff_and_no_rotation(self):
        events = self.module.audit(raw(sample()), "progress")
        initial, terminal = events[0]["pre"], events[-1]["post"]
        first = initial["canonical"][0]
        self.assertEqual((first["origin"], first["originTime"], initial["activeSnapshot"]),
                         (25, 300, 24))
        self.assertLess(initial["activeSnapshot"], first["origin"])
        self.assertEqual((first["bftTime"], first["parentAnchor"]), (300, 25))
        self.assertEqual(initial["history"][0], (25, ZERO))
        self.assertEqual(self.module.EPOCH_LENGTH, 16)
        self.assertLess(terminal["head"], self.module.EPOCH_LENGTH - 1)
        self.assertTrue(all(record["activeSnapshot"] == 24 for record in terminal["records"]))
        self.assertEqual((terminal["job"]["dependency"], terminal["job"]["statement"][19]), (24, 24))
        self.assertEqual(VIEWS[0]["checkpoint"], (0, 100, 0, 0))
        model = Path(__file__).resolve().parents[1] / "EtnaRuleRange.tla"
        self.assertIn("EpochLength == 16", model.read_text())
        self.assertIn("ProtocolInitialCompatibility ==", model.read_text())
        stages = sample()
        old = stages[0][0]
        old["activeSnapshot"] = 1
        old["canonical"] = (dict(old["canonical"][0], origin=1, originTime=12,
                                  bftTime=12, parentAnchor=1),) + old["canonical"][1:]
        with self.assertRaisesRegex(ValueError, "cutoff must strictly precede origin"):
            self.module.audit(raw(stages), "progress")
        invalid = (dict(VIEWS[0], checkpoint=(0, 100, 200, 0)),) + VIEWS[1:]
        with self.assertRaisesRegex(ValueError, "genesis checkpoint Comet"):
            self.module.resolve_blocks(BLOCKS, invalid)


if __name__ == "__main__":
    unittest.main()
