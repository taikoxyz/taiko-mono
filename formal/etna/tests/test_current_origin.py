"""Permissionless Unzen-to-Etna start, finality and rollback vectors."""

from dataclasses import replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]


class OriginTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/origin.py").is_file(),
            "Z06 origin model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        import_path = sys.path.copy()
        self.m = import_module("formal.etna.current_rules.origin")
        self.assertEqual(sys.path, import_path)

    def apply(self, state, *actions):
        for action in actions:
            state = self.m.step(state, action).state
        return state

    def refuse(self, state, action, reason):
        m = self.m
        snapshot = repr(state)
        with self.assertRaisesRegex(m.Refused, reason):
            m.step(state, action)
        self.assertEqual(repr(state), snapshot)

    def node(self, target, **changes):
        m = self.m
        good = m.NodeEvidence(
            target, 100, "etna-implementation", 100,
            m.Header(1, "A-h1", "A-r1", 99), "etna-implementation",
        )
        return replace(good, **changes)

    def test_start_writes_full_coupled_frame_once(self):
        m = self.m
        pre = m.initial(timestamp=100)
        result = m.step(pre, m.SetOrigin(1))
        start = m.Start(1, "A-h1", "A-r1", 10)
        record = m.Slot285(1, "A-h1", None, 0, 1, 0)
        gen0 = m.GenerationOrigin(0, 1, 10, 100)
        self.assertEqual(result.state, replace(
            pre, start=start, last_checkpoint=(1, "A-h1"), slot285=(record,),
            generation_origins=(gen0,), fi_head=0, fi_tail=0,
        ))
        self.assertEqual(result.events, (("start", start, record, gen0),))
        self.assertGreater(pre.unzen.fi_head, 0)
        self.assertEqual(result.state.epoch_len, pre.epoch_len)
        self.assertEqual(result.state.active_committee_snapshot, pre.genesis_cutoff)
        self.refuse(result.state, m.SetOrigin(1), "start already written")
        self.refuse(result.state, m.SetOrigin(2), "start already written")

    def test_latch_uses_independently_reached_live_cutoff(self):
        m = self.m
        self.refuse(m.initial(timestamp=99), m.SetOrigin(1), "fork not reached")
        pre = m.initial(timestamp=100)
        for cutoff in (0, 101):
            with self.subTest(cutoff=cutoff):
                self.refuse(replace(pre, propose_cutoff=cutoff), m.SetOrigin(1), "proposal cutoff")
        self.assertEqual(self.apply(replace(pre, propose_cutoff=100), m.SetOrigin(1)).start.height, 1)
        delayed = self.apply(replace(pre, propose_cutoff=101), m.Advance(11, 101), m.SetOrigin(1))
        self.assertEqual(delayed.start.l1_block, 11)

    def test_unzen_forced_inclusion_closes_before_proposals_at_its_own_cutoff(self):
        m = self.m
        before = replace(m.initial(), timestamp=73)
        cp = m.Checkpoint(2, "A-h2", "A-r2")
        saved = m.step(before, m.SaveUnzenForcedInclusion())
        self.assertEqual(saved, m.Transition(
            replace(before, unzen=replace(before.unzen, fi_tail=5)), (("unzen-fi", 4),),
        ))
        cutoff = replace(before, timestamp=74)
        self.refuse(cutoff, m.SaveUnzenForcedInclusion(), "Unzen FI cutoff")
        self.assertEqual(self.apply(cutoff, m.Propose(cp)).unzen.pending, (cp,))

    def test_latch_refuses_uninitialized_missing_immutables_and_wrong_height(self):
        m = self.m
        pre = m.initial(timestamp=100)
        self.refuse(replace(pre, initialized=False), m.SetOrigin(1), "not initialized")
        self.refuse(replace(pre, unzen_inbox=None), m.SetOrigin(1), "missing immutable")
        self.refuse(replace(pre, fork_time=0), m.SetOrigin(1), "missing immutable")
        for height in (-1, 0, 2**48, True):
            with self.subTest(height=height):
                self.refuse(pre, m.SetOrigin(height), "uint48")
        for height in (4, 2**48 - 1):
            cp = m.Checkpoint(height, "A-h1", "edge-root")
            written = self.apply(replace(pre, unzen_checkpoints=(cp,)), m.SetOrigin(height))
            self.assertEqual(written.start, m.Start(height, "A-h1", "edge-root", 10))

    def test_start_l1_block_fits_its_slot272_word(self):
        m = self.m
        pre = m.initial(timestamp=99)
        last = self.apply(pre, m.Advance(2**48 - 1, 100), m.SetOrigin(1))
        self.assertEqual(last.start.l1_block, 2**48 - 1)
        self.assertEqual(last.generation_origins[0].l1_block, 2**48 - 1)
        overflow = self.apply(pre, m.Advance(2**48, 100))
        self.refuse(overflow, m.SetOrigin(1), "L1 start block outside uint48")

    def test_latch_checks_finalized_hash_checkpoint_root_and_each_read(self):
        m = self.m
        pre = m.initial(timestamp=100)
        for offered, reason in (
            ((), "missing checkpoint"),
            ((m.Checkpoint(1, "other-hash", "A-r1"),), "finalized hash mismatch"),
            ((m.Checkpoint(1, "A-h1", None),), "missing state root"),
        ):
            with self.subTest(offered=offered):
                self.refuse(replace(pre, unzen_checkpoints=offered), m.SetOrigin(1), reason)
        self.refuse(replace(pre, unzen=replace(pre.unzen, last_finalized_hash=None)),
                    m.SetOrigin(1), "finalized hash mismatch")
        for field in ("cutoff_readable", "core_readable", "checkpoint_readable"):
            with self.subTest(field=field):
                self.refuse(replace(pre, **{field: False}), m.SetOrigin(1), "read failed")

    def test_proof_before_latch_in_same_block_is_required(self):
        m = self.m
        cp = m.Checkpoint(2, "A-h2", "A-r2")
        self.refuse(m.initial(timestamp=88), m.Propose(cp), "proposal cutoff")
        pending = self.apply(m.initial(), m.Propose(cp), m.Advance(10, 100))
        self.assertEqual((pending.unzen.next_proposal_id, pending.unzen.last_finalized_id), (2, 0))
        self.refuse(pending, m.SetOrigin(1), "unfinalized proposals")
        self.refuse(pending, m.SetOrigin(2), "unfinalized proposals")
        self.refuse(pending, m.Prove(False), "Unzen proof")
        self.refuse(pending, m.Prove(signal_accepts=False), "SignalService")
        proved = m.step(pending, m.Prove())
        self.assertEqual(proved.state, replace(
            pending, unzen=replace(
                pending.unzen, last_finalized_id=1, last_finalized_hash="A-h2", pending=None,
            ), unzen_checkpoints=(*pending.unzen_checkpoints, cp),
        ))
        self.assertEqual(proved.events, (("forward", cp), ("unzen-proof", 1, cp)))
        self.refuse(proved.state, m.SetOrigin(1), "finalized hash mismatch")
        self.assertEqual(self.apply(proved.state, m.SetOrigin(2)).start, m.Start(2, "A-h2", "A-r2", 10))

    def test_forwarder_closes_for_every_height_and_fi_starts_empty(self):
        m = self.m
        pre = m.initial(timestamp=100)
        cp = m.Checkpoint(2**48 - 1, "historic", "old-root")
        self.refuse(pre, m.SaveForcedInclusion(), "start not written")
        self.refuse(pre, m.ForwardCheckpoint("unrelated", cp), "wrong forwarder")
        self.refuse(pre, m.ForwardCheckpoint("unzen-inbox", cp, False), "SignalService")
        self.assertEqual(m.step(pre, m.ForwardCheckpoint("unzen-inbox", cp)), m.Transition(
            replace(pre, unzen_checkpoints=(*pre.unzen_checkpoints, cp)), (("forward", cp),),
        ))
        before_init = replace(pre, initialized=False)
        self.assertIn(cp, self.apply(before_init, m.ForwardCheckpoint("unzen-inbox", cp)).unzen_checkpoints)
        started = self.apply(pre, m.SetOrigin(1))
        for height in (0, 1, 2, 2**48 - 1):
            self.refuse(started, m.ForwardCheckpoint("unzen-inbox", replace(cp, height=height)),
                        "forwarding closed")
        offered = m.step(started, m.SaveForcedInclusion())
        self.assertEqual(offered, m.Transition(replace(started, fi_tail=1), (("fi", 0),)))

    def test_reorg_discards_every_orphan_origin_write(self):
        m = self.m
        cp = m.Checkpoint(2, "A-h2", "A-r2")
        orphan = self.apply(
            m.initial(), m.Propose(cp), m.Advance(10, 100), m.Prove(), m.SetOrigin(2),
            m.SaveForcedInclusion(),
        )
        other = m.initial("B", timestamp=100)
        self.assertFalse(m.node_can_sign(orphan, self.node(orphan.slot285[0])))
        self.refuse(orphan, m.Reorg(other, False), "canonical branch")
        self.assertEqual(m.step(orphan, m.Reorg(other)), m.Transition(other, (("reorg", "A", "B"),)))
        canonical = self.apply(orphan, m.Reorg(other), m.SetOrigin(1), m.Advance(40, 460), m.Finalize())
        self.assertEqual(canonical.start, m.Start(1, "B-h1", "B-r1", 10))
        self.assertEqual(canonical.fi_tail, 0)
        self.assertNotIn(cp, canonical.unzen_checkpoints)
        self.refuse(canonical, m.Reorg(orphan), "finalized start")

    def test_node_needs_own_finality_and_checks_authenticated_start(self):
        m = self.m
        started = self.apply(m.initial(timestamp=100), m.SetOrigin(1))
        ready = self.node(started.slot285[0])
        self.assertFalse(m.node_can_sign(started, ready))
        self.refuse(started, m.Finalize(False), "finality")
        finalized = self.apply(started, m.Advance(40, 460), m.Finalize())
        self.assertTrue(m.node_can_sign(finalized, ready))
        for changes in (
            {"state_authenticated": False}, {"header": None},
            {"header": replace(ready.header, timestamp=100)},
            {"header": replace(ready.header, block_hash="wrong")},
            {"header": replace(ready.header, state_root="wrong")},
            {"proxy_implementation": "wrong"}, {"effective_fork_time": 101},
            {"getter_address": "proxy"}, {"getter_fork_time": 101},
            {"target": replace(ready.target, comet_hash="wrong")},
        ):
            with self.subTest(changes=changes):
                self.assertFalse(m.node_can_sign(finalized, replace(ready, **changes)))
        bad_view = replace(finalized, finalized=replace(
            finalized.finalized, unzen_last_hash="other-hash",
        ))
        self.assertFalse(m.node_can_sign(bad_view, ready))

    def test_guest_uses_start_header_and_storage_proof_but_no_local_getter(self):
        m = self.m
        state = self.apply(m.initial(timestamp=100), m.SetOrigin(1), m.Advance(40, 460), m.Finalize())
        ready = self.node(state.slot285[0], effective_fork_time=101, getter_address="proxy")
        self.assertFalse(m.node_can_sign(state, ready))
        guest = m.GuestEvidence(ready.header, "etna-implementation")
        self.assertTrue(m.guest_accepts_origin(state, 1, guest))
        for changes in (
            {"storage_proof_authenticated": False},
            {"header": replace(guest.header, timestamp=100)},
            {"header": replace(guest.header, block_hash="other-hash")},
            {"header": replace(guest.header, state_root="other-root")},
            {"proxy_implementation": "other-implementation"},
        ):
            self.assertFalse(m.guest_accepts_origin(state, 1, replace(guest, **changes)))
        self.assertFalse(m.guest_accepts_origin(state, 2, guest))
        self.assertEqual(state.start, m.Start(1, "A-h1", "A-r1", 10))

    def test_external_landing_allows_pruned_join_with_correct_fork_only(self):
        m = self.m
        state = self.apply(m.initial(timestamp=100), m.SetOrigin(1), m.Advance(40, 460))
        self.assertFalse(m.node_can_sign(state, self.node(state.slot285[0], effective_fork_time=101)))
        land = m.Land(1, m.Checkpoint(2, "etna-h2", "etna-r2"), "comet-h2", 0, 6)
        self.refuse(state, replace(land, proof_authenticated=False), "external proof")
        self.assertEqual(m.step(state, land).events, (("land", land.checkpoint, m.Slot285(
            2, "etna-h2", "comet-h2", 0, 1, 0,
        ), 6),))
        landed = self.apply(state, land, m.Advance(80, 940), m.Finalize())
        record = m.Slot285(2, "etna-h2", "comet-h2", 0, 1, 0)
        pruned = m.NodeEvidence(record, 100, "etna-implementation", 100)
        self.assertTrue(m.node_can_sign(landed, pruned))
        self.assertFalse(m.node_can_sign(landed, replace(pruned, effective_fork_time=101)))
        self.assertFalse(m.node_can_sign(landed, replace(pruned, getter_address="proxy")))
        self.assertFalse(m.node_can_sign(landed, replace(pruned, target=state.slot285[0])))

    def test_external_landing_preserves_own_finalized_view_when_local_override_rejects(self):
        m = self.m
        unobserved = self.apply(m.initial(timestamp=100), m.SetOrigin(1), m.Advance(40, 460))
        observed = self.apply(unobserved, m.Finalize())
        start_record = m.Slot285(1, "A-h1", None, 0, 1, 0)
        view = m.FinalizedView(m.Start(1, "A-h1", "A-r1", 10), start_record, 100, "A-h1")
        evidence = self.node(start_record, header=m.Header(1, "A-h1", "A-r1", 75))
        wrong_local_fork = replace(evidence, effective_fork_time=101)
        self.assertIsNone(unobserved.finalized)
        self.assertEqual(observed.finalized, view)
        self.assertTrue(m.node_can_sign(observed, evidence))
        self.assertFalse(m.node_can_sign(observed, wrong_local_fork))

        cp = m.Checkpoint(2, "etna-h2", "etna-r2")
        land = m.Land(1, cp, "comet-h2", 0, 6)
        landed_record = m.Slot285(2, "etna-h2", "comet-h2", 0, 1, 0)
        expected = m.Transition(
            replace(
                unobserved, last_checkpoint=(2, "etna-h2"),
                slot285=(start_record, landed_record), etna_checkpoints=(cp,),
            ),
            (("land", cp, landed_record, 6),),
        )
        self.assertEqual(m.step(unobserved, land), expected)
        after_observed = m.step(observed, land)
        self.assertEqual(after_observed, replace(expected, state=replace(expected.state, finalized=view)))
        self.assertFalse(m.node_can_sign(after_observed.state, wrong_local_fork))

    def test_first_landing_rollback_keeps_start_unzen_checkpoint_and_later_generation(self):
        m = self.m
        cp = m.Checkpoint(2, "etna-h2", "etna-r2")
        initial = self.apply(m.initial(timestamp=100), m.SetOrigin(1), m.SaveForcedInclusion(), m.Advance(40, 460))
        changed = self.apply(
            initial, m.Land(1, cp, "comet-h2", 1, 6), m.Advance(80, 940), m.Recover(),
        )
        self.assertEqual(changed.generation_origins[-1], m.GenerationOrigin(1, 2, 80, 940))
        self.refuse(changed, m.RollbackFirstLanding(False), "rollback authorization")
        result = m.step(changed, m.RollbackFirstLanding())
        self.assertEqual(result.state, replace(
            initial, l1_block=80, timestamp=940, generation=1,
            generation_origins=changed.generation_origins, recovery_nonce=2,
        ))
        self.assertEqual(result.events, (("rollback-first", cp, initial.slot285[0]),))
        self.refuse(result.state, m.SetOrigin(1), "start already written")
        self.refuse(result.state, m.Land(1, cp, "comet-h2", 1, 6), "generation origin")
        evidence = m.GuestEvidence(m.Header(1, "A-h1", "A-r1", 99), "etna-implementation")
        self.assertTrue(m.guest_accepts_origin(result.state, 1, evidence))
        self.assertFalse(m.guest_accepts_origin(result.state, 2, evidence))
        replacement = m.Checkpoint(2, "recovered-h2", "recovered-r2")
        recovered = self.apply(
            result.state, m.Advance(160, 1900), m.Recover(), m.Advance(240, 2860),
            m.Land(1, replacement, "replacement-comet", 1, 160),
        )
        self.assertEqual(recovered.etna_checkpoints, (replacement,))
        self.assertEqual(recovered.start, initial.start)
        self.assertEqual(recovered.unzen_checkpoints, initial.unzen_checkpoints)
        self.assertEqual(recovered.slot285[-1].generation, 2)
        self.assertEqual(recovered.active_committee_snapshot, 160)

    def test_exhausted_bank_and_cap(self):
        m = self.m
        result = m.assess_bank()
        self.assertEqual(result.status, "EXHAUSTED", result.error)
        landings = [edge for edge in result.exploration.accepted if isinstance(edge.action, m.Land)]
        self.assertTrue(landings)
        for edge in landings:
            self.assertGreater(edge.pre.l1_block, edge.pre.start.l1_block)
            self.assertEqual(edge.action.active_committee_snapshot, edge.pre.genesis_cutoff)
            self.assertIsNone(edge.pre.finalized)
        consuming_landings = {edge.pre for edge in landings if edge.action.fi_head > 0}

        for edge in result.exploration.accepted:
            if isinstance(edge.action, m.SaveForcedInclusion):
                self.assertFalse(edge.post in consuming_landings,
                                 "first landing consumes FI appended in its own block")
            if isinstance(edge.action, m.Recover):
                landed = next(item for item in result.exploration.path_to(edge.pre)
                              if isinstance(item.action, m.Land))
                self.assertGreater(edge.pre.l1_block, landed.pre.l1_block)
            if isinstance(edge.action, m.Reorg) and edge.pre.start is not None:
                self.assertLessEqual(edge.pre.l1_block, 10)
                self.assertIsNone(edge.pre.finalized)
        self.assertEqual(set(result.witnesses), set(m.REQUIRED_WITNESSES))
        self.assertGreater(len(result.exploration.accepted), 0)
        self.assertGreater(len(result.exploration.refused), 0)
        self.assertEqual(m.assess_bank(max_states=1).status, "INCONCLUSIVE")


if __name__ == "__main__":
    unittest.main()
