"""Selected replacement deadline, bridge and acknowledgment histories."""

from dataclasses import replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]


class ReplacementTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/replacement.py").is_file(),
            "Z07 replacement model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        import_path = sys.path.copy()
        self.m = import_module("formal.etna.current_rules.replacement")
        self.assertEqual(sys.path, import_path)

    def apply(self, state, *actions):
        for action in actions:
            state = self.m.step(state, action).state
        return state

    def refuse(self, state, action, reason):
        snapshot = repr(state)
        with self.assertRaisesRegex(self.m.Refused, reason):
            self.m.step(state, action)
        self.assertEqual(repr(state), snapshot)

    def sent(self, *, pending=False, plan=None):
        m = self.m
        plan = m.default_plan() if plan is None else plan
        return self.apply(m.initial(initial_pending=pending), m.Prepare(plan),
                          m.AdvanceL1(9), m.Send(plan.operation_id))

    def receipt(self, state, operation_id="first"):
        return next(entry.delivery.receipt for entry in state.operations
                    if entry.plan.operation_id == operation_id)

    def relayed(self, state, operation_id="first", timestamp=19):
        m = self.m
        receipt = self.receipt(state, operation_id)
        state = self.apply(state, m.AdvanceL1(21), m.AdvanceL2(timestamp))
        return self.apply(state, m.Process(receipt, m.relay_proof(state, receipt)))

    def proved(self, state, finalized_at=28, now=29, *, block=None):
        m = self.m
        endpoint = state.l2 if block is None else block
        state = self.apply(state, m.AdvanceL1(26), m.ProveUnzen(endpoint),
                           m.AdvanceL1(now))
        return state, m.FinalizedProof(state.checkpoints[-1], finalized_at)

    def commit_frame(self, *, plan=None):
        state, proof = self.proved(self.relayed(self.sent(plan=plan)))
        return state, self.m.ack_proof(state, proof)

    def ready(self, state, proof, schedule, phase_a_proofs=(), **changes):
        query = self.m.CheckReadiness(proof, schedule, phase_a_proofs, **changes)
        outcome = self.m.step(state, query)
        self.assertEqual(outcome.state, state)
        self.assertEqual(outcome.events[0][0], "readiness")
        return outcome.events[0][1]

    def test_prepare_pins_full_plan_and_exclusive_l1_send_preserves_live_config(self):
        m = self.m
        plan = m.default_plan()
        self.assertEqual((plan.a, plan.e, plan.b, plan.c, plan.rollout_budget),
                         (10, 20, 30, 40, 70))
        self.assertEqual((plan.old.l1.fork_time, plan.new.l1.fork_time,
                          plan.new.l1.fi_cutoff, plan.new.l1.proposal_cutoff),
                         (100, 200, 140, 188))
        base = m.initial()
        for changes in ({"a": 20}, {"e": 30}, {"b": 31}, {"c": 41},
                        {"proposal_lead": 60}, {"route": replace(plan.route, l2_chain=1)},
                        {"predecessors": ("future-implementation",)}):
            with self.subTest(changes=changes):
                self.refuse(base, m.Prepare(replace(plan, **changes)), "plan")
        pre = self.apply(base, m.Prepare(plan), m.AdvanceL1(9))
        self.refuse(pre, m.Prepare(plan), "operation ID")
        self.refuse(replace(pre, start_written=True), m.Send("first"), "start written")
        self.refuse(replace(pre, l1=plan.new.l1), m.Send("first"), "old L1")
        sent = m.step(pre, m.Send("first"))
        receipt = self.receipt(sent.state)
        self.assertEqual((receipt.message.message_id, receipt.message.execution_id,
                          receipt.message.target, receipt.sent_at), (7, 0, "controller", 9))
        self.assertEqual((sent.state.l1, sent.state.l2, sent.state.checkpoints),
                         (pre.l1, pre.l2, pre.checkpoints))
        self.assertEqual(sent.events, (("message-sent", receipt),))
        self.refuse(sent.state, m.Send("first"), "already sent")
        at_a = self.apply(pre, m.AdvanceL1(10))
        self.refuse(at_a, m.Send("first"), "phase A deadline")

    def test_new_proof_binds_exact_receipt_route_and_active_service(self):
        m = self.m
        state = self.apply(self.sent(), m.AdvanceL1(21), m.AdvanceL2(19))
        receipt = self.receipt(state)
        proof = m.relay_proof(state, receipt)
        for changes in ({"message_hash": "wrong"}, {"source": "other-bridge"},
                        {"source_chain": 3}, {"signal_service": "wrong-proxy"},
                        {"active_implementation": "wrong-implementation"},
                        {"checkpoint_l1_timestamp": 8}, {"usable": False},
                        {"authenticated": False}, {"canonical": False}):
            with self.subTest(changes=changes):
                self.refuse(state, m.Process(receipt, replace(proof, **changes)), "relay proof")
        self.refuse(state, m.Process(replace(receipt, message_hash="different"), proof),
                    "exact sent message")
        result = m.step(state, m.Process(receipt, proof))
        self.assertEqual(result.state.operations[0].delivery.status, "DONE")
        self.assertEqual((result.state.l2.installation.address,
                          result.state.l2.installation.fork_time), ("signal-v2", 200))
        self.assertEqual(result.state.l1.fork_time, 100)
        self.assertEqual(len(result.state.l2.acknowledgments), 1)
        self.refuse(result.state, m.Process(receipt, proof), "NEW")

    def test_new_usable_l1_checkpoint_can_have_later_timestamp_than_l2(self):
        m = self.m
        state = self.apply(self.sent(), m.AdvanceL1(21), m.AdvanceL2(19))
        receipt = self.receipt(state)
        proof = replace(m.relay_proof(state, receipt), checkpoint_l1_timestamp=20)
        self.refuse(state, m.Process(receipt, replace(proof, checkpoint_l1_timestamp=22)),
                    "relay proof")
        try:
            result = m.step(state, m.Process(receipt, proof))
        except m.Refused as error:
            self.fail(f"usable L1 checkpoint and on-time L2 invocation refused: {error}")
        self.assertEqual(result.state.operations[0].delivery.status, "DONE")
        self.assertEqual((result.state.l2.timestamp, result.state.l2.installation.fork_time),
                         (19, 200))

    def test_new_failure_and_retry_failure_have_distinct_atomic_effects(self):
        m = self.m
        state = self.apply(self.sent(), m.AdvanceL1(21), m.AdvanceL2(19))
        receipt = self.receipt(state)
        proof = m.relay_proof(state, receipt)
        for invocation in (m.Invocation(gas_ok=False),
                           m.Invocation(observed_address="wrong"),
                           m.Invocation(observed_fork_time=201),
                           m.Invocation(signal_ok=False)):
            with self.subTest(invocation=invocation):
                failed = m.step(state, m.Process(receipt, proof, invocation))
                self.assertEqual(failed.state.operations[0].delivery.status, "RETRIABLE")
                self.assertEqual(failed.state.l2, state.l2)
                self.assertEqual(failed.events[0][:3], ("bridge", receipt, "RETRIABLE"))
                self.refuse(failed.state, m.Retry(receipt, invocation), "retry failed")
        self.refuse(failed.state, m.Retry(receipt, last_attempt=True), "retry mode")
        done = self.apply(failed.state, m.Retry(receipt, caller="another-relayer"))
        self.assertEqual(done.operations[0].delivery.status, "DONE")
        self.assertEqual(len(done.l2.acknowledgments), 1)

    def test_execution_uses_l2_time_and_equal_deadline_cannot_mutate_l2(self):
        m = self.m
        done = self.relayed(self.sent())
        self.assertEqual((done.l1_timestamp, done.l2.timestamp), (21, 19))
        self.assertEqual(done.l2.installation.fork_time, 200)
        state = self.apply(self.sent(), m.AdvanceL1(19), m.AdvanceL2(20))
        receipt = self.receipt(state)
        failed = m.step(state, m.Process(receipt, m.relay_proof(state, receipt)))
        self.assertEqual(failed.state.l2, state.l2)
        self.assertEqual(failed.events, (("bridge", receipt, "RETRIABLE", "L2 deadline"),))
        self.refuse(failed.state, m.Retry(receipt), "L2 deadline")

    def test_pending_initial_message_cannot_overwrite_replacement_before_its_deadline(self):
        m = self.m
        state = self.relayed(self.sent(pending=True))
        receipt = state.initial_delivery.receipt
        self.assertEqual(state.initial_delivery.status, "NEW")
        self.assertLess(state.l2.timestamp, receipt.message.deadline)
        failed = m.step(state, m.Process(receipt, m.relay_proof(state, receipt)))
        self.assertEqual(failed.events, (("bridge", receipt, "RETRIABLE", "L2 predecessor"),))
        self.assertEqual(failed.state.l2, state.l2)

    def test_admitted_proof_uses_l2_endpoint_independently_of_l1_inclusion_time(self):
        m = self.m
        # The proof is admitted by premise. A normal block can share the proposal
        # timestamp, while forced/default derivation can produce a later value.
        for timestamp in (21, 25):
            with self.subTest(l2_timestamp=timestamp):
                state = self.apply(self.sent(), m.AdvanceL1(21), m.AdvanceL2(timestamp))
                self.refuse(state, m.ProveUnzen(state.l2, admitted=False),
                            "Unzen checkpoint proof")
                try:
                    result = m.step(state, m.ProveUnzen(state.l2, admitted=True))
                except m.Refused as error:
                    self.fail(f"admitted proof refused solely by cross-chain clocks: {error}")
                checkpoint = m.Checkpoint(state.l2, 21)
                self.assertEqual(result, m.Transition(
                    replace(state, checkpoints=(*state.checkpoints, checkpoint)),
                    (("checkpoint", checkpoint),),
                ))
                later = self.apply(result.state, m.AdvanceL1(29))
                finalized = m.FinalizedProof(checkpoint, 28)
                self.assertEqual(self.ready(later, finalized, m.default_plan().old), "OPEN")

    def test_phase_b_consumes_exact_ack_and_preserves_checkpoint_route_and_unrelated_config(self):
        m = self.m
        state, proof = self.commit_frame()
        plan = m.default_plan()
        for changes in ({"source": "other-controller"}, {"source_chain": 1},
                        {"signal_service": "wrong-service"}):
            self.refuse(state, m.Commit("first", replace(proof, **changes)), "ack route")
        for field, value in (
            ("old", plan.new), ("new", plan.old), ("l1_chain", 2), ("l2_chain", 3),
            ("target", "wrong-target"),
        ):
            wrong = replace(proof, acknowledgment=replace(proof.acknowledgment,
                                                           **{field: value}))
            self.refuse(state, m.Commit("first", wrong), "ack context")
        for flag in ("authenticated", "canonical", "finalized"):
            wrong = replace(proof, finality=replace(proof.finality, **{flag: False}))
            self.refuse(state, m.Commit("first", wrong), "finalized Unzen proof")
        self.refuse(replace(state, start_written=True), m.Commit("first", proof), "start written")
        self.refuse(replace(state, l1=replace(state.l1, unrelated=("modified",))),
                    m.Commit("first", proof), "old L1")
        wrong_install = replace(plan.new.l1, unrelated=("changed",))
        self.refuse(state, m.Commit("first", proof, installed=wrong_install), "L1 postcondition")
        self.assertEqual(self.ready(state, proof.finality, plan.new), "CLOSED")
        result = m.step(state, m.Commit("first", proof))
        self.assertEqual(result.state.l1, plan.new.l1)
        self.assertEqual(result.state.l1.checkpoint_store, state.l1.checkpoint_store)
        self.assertEqual(result.state.l1.unrelated, state.l1.unrelated)
        self.assertEqual(result.state.checkpoints, state.checkpoints)
        self.assertEqual(result.events, (("phase-b", "first", plan.new.l1),))
        self.assertEqual(self.ready(result.state, proof.finality, plan.new), "CLOSED")
        finalized = self.apply(result.state, m.AdvanceL1(45))
        config = m.InstalledConfigProof(plan.new.l1, 29, 42)
        self.assertEqual(self.ready(finalized, proof.finality, plan.new, config_proof=config),
                         "OPEN")
        for changes in ({"config": plan.old.l1}, {"included_at": 28}, {"finalized_at": 29},
                        {"canonical": False}, {"authenticated": False}, {"finalized": False}):
            with self.subTest(changes=changes):
                self.assertEqual(self.ready(finalized, proof.finality, plan.new,
                                            config_proof=replace(config, **changes)), "CLOSED")
        self.assertEqual(self.ready(result.state, proof.finality, plan.new, other_checks=False),
                         "CLOSED")

    def test_phase_b_authenticates_signal_in_finalized_descendant_checkpoint(self):
        m = self.m
        executed = self.relayed(self.sent())
        (emission,) = executed.l2.acknowledgments
        later_block = self.apply(executed, m.AdvanceL2(20))
        self.assertEqual(later_block.l2.acknowledgments, ())
        descendant, finalized = self.proved(later_block)
        self.assertEqual(tuple(checkpoint.block.timestamp for checkpoint in descendant.checkpoints),
                         (0, 20))
        proof = m.AckProof(finalized, emission.acknowledgment, 2, "controller", "l1-signal")
        try:
            result = m.step(descendant, m.Commit("first", proof))
        except m.Refused as error:
            self.fail(f"actual stored acknowledgment under finalized descendant refused: {error}")
        plan = m.default_plan()
        self.assertEqual(result, m.Transition(replace(
            descendant, l1=plan.new.l1, selected=plan.new, committed_at=29,
            operations=(replace(descendant.operations[0], committed=True),),
        ), (("phase-b", "first", plan.new.l1),)))
        self.assertEqual(descendant.l2.stored_signals, (emission,))
        self.assertEqual(m.ack_proof(descendant, finalized), proof)

    def test_phase_b_accepts_exact_signal_and_release_rechecks_proved_installation(self):
        m = self.m
        plan = m.default_plan()
        later = self.apply(self.relayed(self.sent()), m.AdvanceL2(20))
        config = m.InstalledConfigProof(plan.new.l1, 29, 42)
        for installation, expected in (
            (m.Installation("signal-v2", 200), ("OPEN", "replacement checks satisfied")),
            (m.Installation("signal-v3", 201), ("CLOSED", "proven L2 implementation or fork mismatch")),
        ):
            with self.subTest(installation=installation):
                # A diagnostic later installation is admitted here as a canonical
                # observation outside the compliant serialized action bank.
                observed = replace(later, l2=replace(later.l2, installation=installation))
                state, finality = self.proved(observed)
                ack = m.ack_proof(state, finality)
                self.assertEqual((ack.acknowledgment.operation_id, ack.acknowledgment.target),
                                 ("first", "signal-v2"))
                try:
                    result = m.step(state, m.Commit("first", ack))
                except m.Refused as error:
                    self.fail(f"Phase B refused the exact authentic controller signal: {error}")
                self.assertEqual(result, m.Transition(replace(
                    state, l1=plan.new.l1, selected=plan.new, committed_at=29,
                    operations=(replace(state.operations[0], committed=True),),
                ), (("phase-b", "first", plan.new.l1),)))
                finalized = self.apply(result.state, m.AdvanceL1(45))
                query = m.CheckReadiness(finality, plan.new, config_proof=config)
                self.assertEqual(m.step(finalized, query), m.Transition(
                    finalized, (("readiness", *expected),),
                ))

    def test_phase_b_authenticates_finalized_non_tip_descendant(self):
        m = self.m
        executed = self.relayed(self.sent())
        after = self.apply(executed, m.AdvanceL2(20))
        tip = self.apply(after, m.AdvanceL2(24))
        self.assertEqual((after.l2.timestamp, after.l2.acknowledgments, tip.l2.timestamp),
                         (20, (), 24))
        try:
            state, finalized = self.proved(tip, block=after.l2)
        except m.Refused as error:
            self.fail(f"known canonical non-tip descendant proof refused: {error}")
        self.assertEqual(tuple(checkpoint.block.timestamp for checkpoint in state.checkpoints),
                         (0, 20))
        self.assertEqual(finalized.checkpoint.block.stored_signals, executed.l2.acknowledgments)
        self.assertEqual(finalized.checkpoint.block.acknowledgments, ())
        plan = m.default_plan()
        result = m.step(state, m.Commit("first", m.ack_proof(state, finalized)))
        self.assertEqual(result, m.Transition(replace(
            state, l1=plan.new.l1, selected=plan.new, committed_at=29,
            operations=(replace(state.operations[0], committed=True),),
        ), (("phase-b", "first", plan.new.l1),)))

    def test_old_release_can_use_finalized_non_tip_expiry_block(self):
        m = self.m
        after = self.apply(self.sent(), m.AdvanceL1(21), m.AdvanceL2(20))
        tip = self.apply(after, m.AdvanceL2(24))
        try:
            state, proof = self.proved(tip, block=after.l2)
        except m.Refused as error:
            self.fail(f"known canonical non-tip old expiry block refused: {error}")
        self.assertEqual((proof.checkpoint.block.timestamp, state.l2.timestamp), (20, 24))
        self.assertEqual(self.ready(state, proof, m.default_plan().old), "OPEN")
        newer, _ = self.proved(tip)
        self.refuse(newer, m.ProveUnzen(after.l2), "Unzen checkpoint proof")

    def test_phase_b_refuses_late_inclusion_and_independently_refuses_insufficient_lead(self):
        m = self.m
        state, proof = self.commit_frame()
        for timestamp in (30, 31):
            late = self.apply(state, m.AdvanceL1(timestamp))
            self.refuse(late, m.Commit("first", proof), "phase B deadline")
            self.assertEqual(self.ready(late, proof.finality, m.default_plan().new), "CLOSED")
        plan = m.default_plan(new_fork_time=101)
        state, proof = self.commit_frame(plan=plan)
        self.assertEqual(plan.new.l1.fork_time - state.l1_timestamp, 72)
        self.refuse(state, m.Commit("first", proof), "new proposal lead")
        on_time = m.default_plan(new_fork_time=109)
        state, proof = self.commit_frame(plan=on_time)
        self.assertEqual(on_time.new.l1.fork_time - state.l1_timestamp, 80)
        self.assertEqual(self.apply(state, m.Commit("first", proof)).l1, on_time.new.l1)

    def test_authentic_ack_of_other_sent_operation_cannot_commit_the_batch(self):
        m = self.m
        first = m.default_plan()
        second = m.default_plan(operation_id="second", e=25)
        state = self.apply(self.sent(), m.Abandon("first"), m.Prepare(second), m.Send("second"))
        state, proof = self.proved(self.relayed(state, "second"))
        ack = m.ack_proof(state, proof)
        self.assertEqual(ack.acknowledgment.operation_id, "second")
        self.refuse(state, m.Commit("first", ack), "ack operation")
        self.assertEqual(self.apply(state, m.Commit("second", ack)).l1, first.new.l1)

    def test_older_replacement_cannot_reinstall_distinct_target_before_its_deadline(self):
        m = self.m
        first = m.default_plan()
        second = m.default_plan(operation_id="second", e=25)
        second = replace(second, new=replace(second.new, l2=replace(
            second.new.l2, address="signal-v2-alternate",
        ), release_hashes=("alternate-release-v2",)))
        state = self.apply(self.sent(), m.Abandon("first"), m.Prepare(second), m.Send("second"))
        staged = self.relayed(state, "second")
        self.assertEqual(staged.l2.installation.address, "signal-v2-alternate")
        earlier = self.receipt(staged)
        self.assertLess(staged.l2.timestamp, first.e)
        failed = m.step(staged, m.Process(earlier, m.relay_proof(staged, earlier)))
        self.assertEqual(failed.events, (("bridge", earlier, "RETRIABLE", "L2 predecessor"),))
        self.assertEqual(failed.state.l2, staged.l2)
        self.refuse(failed.state, m.Retry(earlier), "L2 predecessor")

    def test_governance_preflight_serializes_successful_upgrades_through_phase_b(self):
        m = self.m
        first = m.default_plan()
        second = m.default_plan(operation_id="second", e=25)
        state = self.sent()
        self.refuse(state, m.Prepare(second), "governance upgrade still pending")
        state = self.relayed(self.apply(state, m.Abandon("first")))
        self.refuse(state, m.Prepare(second), "governance upgrade still pending")
        state, proof = self.proved(state)
        state = self.apply(state, m.Commit("first", m.ack_proof(state, proof)))
        later = m.Schedule(
            replace(first.new.l1, fork_time=300, fi_cutoff=240, proposal_cutoff=288,
                    unzen_implementation="unzen-v3", inbox_implementation="inbox-v3",
                    guest_images=("guest-v3",)),
            m.Installation("signal-v3", 300), ("client-release-v3",),
        )
        next_plan = replace(second, old=first.new, new=later, a=50, e=80, b=110,
                            c=140, rollout_budget=90, predecessors=("signal-v2",))
        state = self.apply(state, m.Prepare(next_plan), m.AdvanceL1(49), m.Send("second"))
        self.assertEqual(self.receipt(state, "second").message.message_id, 8)
        self.assertEqual(state.l1, first.new.l1)

    def test_old_readiness_requires_one_proven_block_covering_all_sent_deadlines(self):
        m = self.m
        first = m.default_plan()
        second = m.default_plan(operation_id="second", e=25)
        state = self.apply(self.sent(), m.Abandon("first"), m.Prepare(second), m.Send("second"),
                           m.Abandon("second"), m.AdvanceL1(21))
        for timestamp, expected in ((19, "CLOSED"), (20, "CLOSED"), (24, "CLOSED"),
                                    (25, "OPEN")):
            with self.subTest(timestamp=timestamp):
                pre = self.apply(state, m.AdvanceL2(timestamp))
                pre, proof = self.proved(pre)
                self.assertEqual(self.ready(pre, proof, first.old), expected)
                self.assertEqual(self.ready(pre, None, first.old), "CLOSED")
                self.assertEqual(self.ready(pre, replace(proof, finalized=False), first.old),
                                 "CLOSED")
        forged = replace(proof, checkpoint=replace(
            proof.checkpoint, block=replace(proof.checkpoint.block, installation=replace(
                proof.checkpoint.block.installation, fork_time=101)),
        ))
        self.assertEqual(self.ready(pre, forged, first.old), "CLOSED")
        wrong_getter = self.apply(state, m.AdvanceL2(25))
        wrong_getter = replace(wrong_getter, l2=replace(
            wrong_getter.l2, installation=m.Installation("signal-v1", 101),
        ))
        wrong_getter, authenticated = self.proved(wrong_getter)
        self.assertEqual(authenticated.checkpoint.block.installation.address, "signal-v1")
        self.assertEqual(self.ready(wrong_getter, authenticated, first.old), "CLOSED")

    def test_unsent_abandonment_or_tip_time_alone_does_not_clear_release(self):
        m = self.m
        plan = m.default_plan()
        state = self.apply(m.initial(), m.Prepare(plan), m.Abandon("first"), m.AdvanceL1(21),
                           m.AdvanceL2(20))
        state, proof = self.proved(state)
        self.assertEqual(self.ready(state, proof, plan.old), "CLOSED")
        expiry = m.PhaseAProof("first", 10, 28)
        self.assertEqual(self.ready(state, proof, plan.old, (expiry,)), "OPEN")
        for changes in ({"observed_at": 9}, {"authenticated": False}, {"canonical": False},
                        {"finalized": False}, {"finalized_at": 30}, {"cancelled": True}):
            self.assertEqual(self.ready(state, proof, plan.old, (replace(expiry, **changes),)),
                             "CLOSED")
        pre = self.apply(m.initial(), m.Prepare(plan), m.AdvanceL1(9), m.Cancel("first"), m.AdvanceL1(21),
                         m.AdvanceL2(20))
        self.refuse(pre, m.Send("first"), "phase A cancelled")
        pre, proof = self.proved(pre)
        cancelled = m.PhaseAProof("first", 9, 28, cancelled=True)
        self.assertEqual(self.ready(pre, proof, plan.old, (cancelled,)), "OPEN")

    def test_complete_banks_keep_edges_and_required_witnesses(self):
        m = self.m
        assessment = m.assess_bank()
        self.assertEqual(assessment.status, "EXHAUSTED", assessment.reason)
        self.assertTrue(all(graph.accepted and graph.refused for graph in assessment.graphs.values()))
        for label in ("exact-ack-commit", "authentic-other-operation", "two-sent-expiry",
                      "unsent-expiry", "new-before-e", "retry-before-e", "missed-b-split",
                      "late-initial-predecessor", "phase-a-equality", "phase-b-equality"):
            self.assertIn(label, assessment.witnesses)
            self.assertTrue(assessment.witnesses[label].path)
        small = m.assess_bank(max_states=1)
        self.assertEqual(small.status, "INCONCLUSIVE")
        self.assertIn("state cap", small.reason)
