"""Source-derived observations for the generation-bound schedule projection."""

from dataclasses import replace
from importlib import import_module
import json
from pathlib import Path
import subprocess
import sys
from textwrap import dedent
import unittest


PACKAGE = "formal.etna.current_rules"
ROOT = Path(__file__).resolve().parents[3]
DOCUMENTS = ROOT / "packages/protocol/docs/etna"
MAX48 = 281474976710655
MAX256 = 2**256 - 1


class CurrentGovernanceTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/governance.py").is_file(),
            "Z01 generation-bound schedule model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        self.model = import_module(PACKAGE + ".governance")
        self.explorer = import_module(PACKAGE + ".explorer")

    def observed(self, outcome):
        state = outcome.state
        return state.generation, state.c, state.nonce, state.schedule, outcome.events

    def test_minimum_lead_and_promotion_write_exact_slot_values(self):
        m = self.model
        start = m.initial()
        with self.assertRaisesRegex(self.explorer.Refused, "lead"):
            m.step(start, m.ScheduleRules(expected_generation=0, rules=1, time=1295))
        first = m.step(start, m.ScheduleRules(expected_generation=0, rules=1, time=1296))
        self.assertEqual(self.observed(first), (
            0, 0, 0, (0, 1, 1296, 0), (("RulesScheduleUpdated", 0x510000000000001000000000000),),
        ))
        promoted = m.step(replace(first.state, timestamp=1296), m.ScheduleRules(0, 2, 2592))
        self.assertEqual(self.observed(promoted), (
            0, 0, 0, (1, 2, 2592, 0), (("RulesScheduleUpdated", 0xA20000000000002000000000001),),
        ))
        with self.assertRaisesRegex(self.explorer.Refused, "rules number"):
            m.step(replace(first.state, timestamp=1296), m.ScheduleRules(0, 3, 2592))
        self.assertEqual(first.state.schedule, (0, 1, 1296, 0))

    def test_rescheduled_rules_and_cancellation_have_strict_pending_deadlines(self):
        m = self.model
        early = m.step(m.initial(), m.ScheduleRules(0, 1, 1297)).state
        rescheduled = m.step(early, m.ScheduleRules(0, 1, 2592))
        self.assertEqual(self.observed(rescheduled), (
            0, 0, 0, (0, 1, 2592, 0), (("RulesScheduleUpdated", 0xA20000000000001000000000000),),
        ))
        cancelled = m.step(early, m.ScheduleRules(0, 1, MAX48))
        self.assertEqual(self.observed(cancelled), (
            0, 0, 0, (0, 1, 281474976710655, 0),
            (("RulesScheduleUpdated", 0xFFFFFFFFFFFF000000000001000000000000),),
        ))
        for timestamp in (1, 2):
            with self.subTest(timestamp=timestamp):
                with self.assertRaisesRegex(self.explorer.Refused, "pending rules"):
                    m.step(replace(early, timestamp=timestamp), m.ScheduleRules(0, 1, MAX48))
        self.assertEqual(early.schedule, (0, 1, 1297, 0))

    def test_stop_cancellation_and_replacement_use_strict_old_stop(self):
        m = self.model
        early = m.step(m.initial(), m.ScheduleStop(0, 1297))
        self.assertEqual(self.observed(early), (
            0, 0, 0, (0, 0, 0, 1297), (("RulesScheduleUpdated", 0x511000000000000000000000000000000000000),),
        ))
        for timestamp in (1, 2):
            for stop in (0, 2592):
                with self.subTest(timestamp=timestamp, stop=stop):
                    with self.assertRaisesRegex(self.explorer.Refused, "pending stop"):
                        m.step(replace(early.state, timestamp=timestamp), m.ScheduleStop(0, stop))
        self.assertEqual(self.observed(m.step(early.state, m.ScheduleStop(0, 0))), (
            0, 0, 0, (0, 0, 0, 0), (("RulesScheduleUpdated", 0),),
        ))
        minimum = m.step(m.initial(), m.ScheduleStop(0, 1296)).state
        self.assertEqual(minimum.schedule, (0, 0, 0, 1296))
        with self.assertRaisesRegex(self.explorer.Refused, "pending stop"):
            m.step(minimum, m.ScheduleStop(0, 0))
        with self.assertRaisesRegex(self.explorer.Refused, "lead"):
            m.step(replace(m.initial(), timestamp=1), m.ScheduleStop(0, 1296))

    def test_recovery_carries_pending_schedule_and_structural_recovery_replaces_it(self):
        m = self.model
        with_rules = m.step(m.initial(), m.ScheduleRules(0, 1, 2592)).state
        planned = m.step(with_rules, m.ScheduleStop(0, 2592))
        self.assertEqual(self.observed(planned), (
            0, 0, 0, (0, 1, 2592, 2592), (("RulesScheduleUpdated", 0xA20000000000A20000000000001000000000000),),
        ))
        carried = m.step(planned.state, m.Recover(0, 0, 0, 0, 0))
        self.assertEqual(self.observed(carried), (
            1, 0, 1, (0, 1, 2592, 0), (("RulesScheduleUpdated", 0xA20000000000001000000000000),),
        ))
        self.assertEqual(m.rules_at(carried.state.schedule, 2591), 0)
        self.assertEqual(m.rules_at(carried.state.schedule, 2592), 1)
        for invalid in (1, 3):
            with self.assertRaisesRegex(self.explorer.Refused, "structural rules"):
                m.step(planned.state, m.Recover(0, 0, 0, 0, invalid))
        structural = m.step(planned.state, m.Recover(0, 0, 0, 0, 2))
        self.assertEqual(self.observed(structural), (
            1, 0, 1, (2, 2, 0, 0), (("RulesScheduleUpdated", 0x2000000000002),),
        ))

    def test_stale_generation_rejects_updates_and_cancellations(self):
        m = self.model
        before = m.step(m.initial(), m.ScheduleRules(0, 1, 2592)).state
        recovered = m.step(before, m.Recover(0, 0, 0, 0, 0)).state
        pending = m.step(recovered, m.ScheduleStop(1, 2592))
        for action in (
            m.ScheduleRules(0, 2, 1296), m.ScheduleRules(0, 1, MAX48),
            m.ScheduleStop(0, 1296), m.ScheduleStop(0, 0),
        ):
            with self.subTest(action=action):
                with self.assertRaisesRegex(self.explorer.Refused, "stale generation"):
                    m.step(pending.state, action)
        self.assertEqual(self.observed(pending), (
            1, 0, 1, (0, 1, 2592, 2592), (("RulesScheduleUpdated", 0xA20000000000A20000000000001000000000000),),
        ))
        self.assertEqual(self.observed(m.step(pending.state, m.ScheduleStop(1, 0))), (
            1, 0, 1, (0, 1, 2592, 0), (("RulesScheduleUpdated", 0xA20000000000001000000000000),),
        ))

    def test_rollback_increments_nonce_but_preserves_schedule_generation(self):
        m = self.model
        recovered = m.step(m.initial(), m.Recover(0, 0, 0, 0, 0)).state
        planned = m.step(recovered, m.ScheduleStop(1, 2592)).state
        queued_recovery = m.Recover(1, 0, 1, 0, 0)
        queued_stop_cancel = m.ScheduleStop(1, 0)
        landed = m.step(planned, m.Land(1)).state
        rolled_back = m.step(landed, m.Rollback(0))
        self.assertEqual(self.observed(rolled_back), (1, 0, 2, (0, 0, 0, 2592), ()))
        with self.assertRaisesRegex(self.explorer.Refused, "stale nonce"):
            m.step(rolled_back.state, queued_recovery)
        self.assertEqual(self.observed(m.step(rolled_back.state, queued_stop_cancel)), (
            1, 0, 2, (0, 0, 0, 0), (("RulesScheduleUpdated", 0),),
        ))
        with self.assertRaisesRegex(self.explorer.Refused, "stale generation"):
            m.step(rolled_back.state, m.ScheduleRules(0, 1, 1296))

    def test_caller_initialization_start_and_recovery_authorization(self):
        m = self.model
        before_start = replace(m.initial(), started=False)
        uninitialized = replace(before_start, initialized=False)
        self.assertEqual(m.step(before_start, m.ScheduleStop(0, 1296)).state.schedule, (0, 0, 0, 1296))
        for call in (m.ScheduleRules(0, 1, 1296), m.ScheduleStop(0, 1296),
                     m.Recover(0, 0, 0, 0, 0), m.InvalidateNonce(0)):
            with self.subTest(call=call):
                with self.assertRaisesRegex(self.explorer.Refused, "owner"):
                    m.step(m.initial(), replace(call, owner=False))
                with self.assertRaisesRegex(self.explorer.Refused, "uninitialized"):
                    m.step(uninitialized, call)
        with self.assertRaisesRegex(self.explorer.Refused, "start"):
            m.step(before_start, m.Recover(0, 0, 0, 0, 0))
        now = replace(m.initial(), timestamp=1)
        for call, reason in (
            (m.Recover(1, 0, 0, 1, 0), "stale generation"),
            (m.Recover(0, 1, 0, 1, 0), "stale checkpoint"),
            (m.Recover(0, 0, 1, 1, 0), "stale nonce"),
            (m.Recover(0, 0, 0, 0, 0), "expired"),
            (m.InvalidateNonce(1), "stale nonce"),
        ):
            with self.subTest(call=call), self.assertRaisesRegex(self.explorer.Refused, reason):
                m.step(now, call)
        invalidated = m.step(now, m.InvalidateNonce(0))
        self.assertEqual(self.observed(invalidated), (0, 0, 1, (0, 0, 0, 0), ()))
        self.assertEqual(self.observed(m.step(invalidated.state, m.Recover(0, 0, 1, 1, 0))), (
            1, 0, 2, (0, 0, 0, 0), (("RulesScheduleUpdated", 0),),
        ))

    def test_width_limits_do_not_wrap_and_check_only_values_written(self):
        m = self.model
        last_lead = replace(m.initial(), timestamp=281474976709359)
        self.assertEqual(m.step(last_lead, m.ScheduleStop(0, MAX48)).state.schedule, (0, 0, 0, MAX48))
        next_second = replace(last_lead, timestamp=281474976709360)
        for call in (m.ScheduleRules(0, 1, MAX48), m.ScheduleStop(0, MAX48)):
            with self.assertRaisesRegex(self.explorer.Refused, "lead"):
                m.step(next_second, call)
        self.assertEqual(self.observed(m.step(next_second, m.ScheduleStop(0, 0))), (
            0, 0, 0, (0, 0, 0, 0), (("RulesScheduleUpdated", 0),),
        ))
        with self.assertRaisesRegex(self.explorer.Refused, "uint48"):
            m.step(last_lead, m.ScheduleStop(0, 281474976710656))
        max_rules = replace(m.initial(), schedule=(MAX48, MAX48, 0, 0))
        self.assertEqual(m.step(max_rules, m.ScheduleRules(0, MAX48, 1296)).state.schedule, (
            MAX48, MAX48, 1296, 0,
        ))
        with self.assertRaisesRegex(self.explorer.Refused, "uint48"):
            m.step(max_rules, m.ScheduleRules(0, 281474976710656, 1296))
        with self.assertRaisesRegex(self.explorer.Refused, "uint48"):
            m.step(replace(m.initial(), generation=MAX48), m.Recover(MAX48, 0, 0, 0, 0))
        with self.assertRaisesRegex(self.explorer.Refused, "uint256"):
            m.step(replace(m.initial(), timestamp=MAX256), m.ScheduleStop(0, 0))
        for call in (m.Recover(0, 1, MAX256, 0, 0), m.InvalidateNonce(MAX256), m.Rollback(0)):
            with self.subTest(call=call), self.assertRaisesRegex(self.explorer.Refused, "uint256"):
                m.step(replace(m.initial(), c=1, nonce=MAX256), call)

    def test_action_bank_distinguishes_bound_omissions_from_refusals(self):
        m = self.model
        model_boundary = replace(m.initial(), generation=2, c=2, nonce=3, schedule=(3, 3, 0, 0))
        outside = (
            (m.Land(3), ("c",)),
            (m.InvalidateNonce(3), ("nonce",)),
            (m.Recover(2, 2, 3, 0, 0), ("generation", "nonce")),
            (m.ScheduleRules(2, 4, 1296), ("nextRules",)),
        )
        omissions = {item.action: item.fields for item in m.bound_omissions(model_boundary)}
        offered = tuple(m.actions(model_boundary))
        for action, fields in outside:
            with self.subTest(action=action):
                self.assertEqual(omissions[action], fields)
                self.assertNotIn(action, offered)
                m.step(model_boundary, action)
        stale = m.Recover(1, 2, 3, 0, 0)
        self.assertIn(stale, offered)
        self.assertNotIn(stale, omissions)
        with self.assertRaisesRegex(self.explorer.Refused, "stale generation"):
            m.step(model_boundary, stale)

    def test_explorer_keeps_distinct_refusal_edges_and_shortest_accepted_paths(self):
        e = self.explorer

        def step(pre, action):
            if action in ("left", "right"):
                raise e.Refused("denied")
            return e.Transition(action, (("update", action),))

        def check(pre, action, outcome):
            self.assertEqual(outcome.events, (("update", action),))

        actions = {0: (1, 2, "left", "right"), 1: (2,), 2: ()}.__getitem__
        result = e.explore(0, actions, step, check, max_states=3)
        self.assertEqual(result.states, frozenset((0, 1, 2)))
        self.assertEqual(len(result.accepted), 3)
        self.assertEqual({(edge.pre, edge.action, edge.reason) for edge in result.refused}, {
            (0, "left", "denied"), (0, "right", "denied"),
        })
        self.assertEqual(tuple(edge.action for edge in result.path_to(2)), (2,))
        self.assertEqual(result.path_to(0), ())
        with self.assertRaisesRegex(RuntimeError, "INCONCLUSIVE"):
            e.explore(0, actions, step, check, max_states=2)
        with self.assertRaisesRegex(AssertionError, "checked edge"):
            def reject_check(*_):
                raise AssertionError("checked edge")
            e.explore(0, actions, step, reject_check, max_states=3)

    def test_explorer_refuses_optimized_interpreter_before_traversal(self):
        probe = dedent("""\
            from dataclasses import replace
            import sys

            sys.path.insert(0, sys.argv[1])
            from formal.etna.current_rules import governance as model
            from formal.etna.current_rules.explorer import Transition, explore

            def actions(state):
                print("traversal started")
                return (model.InvalidateNonce(0),) if state.nonce == 0 else ()

            def invalid_step(pre, action):
                return Transition(replace(pre, nonce=2))

            try:
                graph = explore(model.initial(), actions, invalid_step, model.check, max_states=2)
            except RuntimeError as error:
                print(error)
            else:
                print(f"returned {len(graph.accepted)} unchecked edge")
            """)
        outcome = subprocess.run(
            [sys.executable, "-I", "-S", "-B", "-O", "-c", probe, str(ROOT)],
            check=True, capture_output=True, text=True, timeout=10,
        )
        self.assertRegex(outcome.stdout, r"\AINCONCLUSIVE: .*assertions.*\n\Z")

    def test_complete_declared_schedule_graph_reaches_all_required_witnesses(self):
        m = self.model
        graph = self.explorer.explore(m.initial(), m.actions, m.step, m.check, max_states=100_000)
        self.assertEqual({state.timestamp for state in graph.states}, {0, 1, 2, 1296, 1297, 2592, 2593})
        self.assertEqual({state.generation for state in graph.states}, {0, 1, 2})
        self.assertEqual({state.c for state in graph.states}, {0, 1, 2})
        self.assertEqual({state.nonce for state in graph.states}, {0, 1, 2, 3})
        for predicate in (
            m.witness_minimum_lead, m.witness_carried_rules, m.witness_structural_upgrade,
            m.witness_post_rollback_schedule, m.witness_stale_schedule,
            m.witness_locked_cancellation,
        ):
            with self.subTest(predicate=predicate.__name__):
                self.assertTrue(predicate(graph), "INCONCLUSIVE missing witness")
        stale = m.witness_stale_schedule(graph)
        self.assertEqual(tuple(edge.pre.schedule for edge in stale), ((0, 1, 2592, 2592),) * 4)
        self.assertEqual(tuple(edge.action for edge in stale), (
            m.ScheduleRules(0, 2, 1296), m.ScheduleRules(0, 1, MAX48),
            m.ScheduleStop(0, 1296), m.ScheduleStop(0, 0),
        ))
        self.assertTrue(all(
            (edge.pre.generation, edge.pre.c, edge.pre.nonce, edge.reason) == (1, 0, 1, "stale generation")
            for edge in stale
        ))
        accepted = {edge.action: edge for edge in graph.accepted if edge.pre == stale[0].pre}
        for call, schedule, event in (
            (m.ScheduleRules(1, 2, 1296), (0, 2, 1296, 2592), 0xA20000000000510000000000002000000000000),
            (m.ScheduleRules(1, 1, MAX48), (0, 1, MAX48, 2592), 0xA20FFFFFFFFFFFF000000000001000000000000),
            (m.ScheduleStop(1, 1296), (0, 1, 2592, 1296), 0x510000000000A20000000000001000000000000),
            (m.ScheduleStop(1, 0), (0, 1, 2592, 0), 0xA20000000000001000000000000),
        ):
            with self.subTest(same_generation_control=call):
                self.assertIn(call, accepted)
                edge = accepted[call]
                self.assertEqual(edge.post.schedule, schedule)
                self.assertEqual(edge.events, (("RulesScheduleUpdated", event),))

    def test_source_identity_requires_all_exact_raw_streams_and_grants_source_only(self):
        from formal.etna.conformance.current_spec import MANIFEST_PATH, classify_workspace_documents

        source = import_module(PACKAGE + ".source")
        docs = {
            "packages/protocol/docs/etna/" + name: (DOCUMENTS / name).read_bytes()
            for name in ("SPEC.md", "ACCEPTANCE.md", "SWITCH.md")
        }
        revision = "f556fa94186b0ab604573e8d3a4c4d4fa835dc84"
        workspace = classify_workspace_documents(docs, json.loads(MANIFEST_PATH.read_bytes()))
        if workspace["bundleId"] == revision:
            identity = source.source_identity(docs)
            self.assertEqual((identity["bundleId"], identity["status"], identity["execution"]), (
                revision, "SOURCE_REVIEWED", "NOT_EVALUATED",
            ))
            self.assertEqual(identity["documents"], workspace["documents"])
        else:
            with self.assertRaisesRegex(ValueError, "require exact f556 source"):
                source.source_identity(docs)
        for path, raw in docs.items():
            with self.subTest(path=path), self.assertRaises(ValueError):
                source.source_identity({**docs, path: raw + b"\n"})
        for invalid in ({**docs, "extra": b""}, {"SPEC.md": b""}):
            with self.assertRaises(ValueError):
                source.source_identity(invalid)


if __name__ == "__main__":
    unittest.main()
