"""Evidence boundary regressions; literal contexts are not native execution."""
from copy import deepcopy
import importlib
from pathlib import Path
import sys
import unittest

CONFORMANCE = Path(__file__).resolve().parents[1] / "conformance"
sys.path.insert(0, str(CONFORMANCE))
HISTORICAL_SECONDS = 1699999900


def cold_context():
    cells = []
    for height in (1900, 1901):
        for age in (3599, 3600, 3601):
            accepted = not (height == 1901 and age == 3601)
            cells.append(dict(store="cold-" + str(height) + "-" + str(age),
                              height=height, seconds=HISTORICAL_SECONDS + age,
                              accepted=accepted, result="accept" if accepted else "expired",
                              headerLookups=[1000], validatorLookups=[1000] if accepted else [],
                              beforePending=0, afterPending=int(accepted), afterGossip=False))
    return dict(case="cold-grid", evidenceHeight=1000, historicalSeconds=HISTORICAL_SECONDS,
                historicalNanos=0, voteSeconds=1700000000, voteNanos=123,
                maxAgeNumBlocks=900, maxAgeSeconds=3600, cells=cells,
                voteTimeAlias=dict(seconds=1700000000, nanos=123, accepted=False,
                                   result="historical-time", headerLookups=[1000],
                                   validatorLookups=[], beforePending=0, afterPending=0))


def gossip_context():
    observations = []
    for height in (1900, 1901):
        sent = height == 1900
        old = None if sent else dict(peerHeight=1901, evHeight=1000, maxAgeNumBlocks=900,
                                     lastSeconds=HISTORICAL_SECONDS, lastNanos=0,
                                     maxAgeNanos=3600000000000)
        observations.append(dict(peerHeight=height, branch="send" if sent else "old-info",
                                 sendCount=int(sent), channel=56 if sent else None,
                                 evidenceCount=int(sent), oldInfo=old,
                                 exitMethod="runtime-goroutine-profile", broadcastAtStart=0,
                                 broadcastAtObservation=1, broadcastAfterQuit=0))
    return dict(case="gossip", evidenceHeight=1000, historicalSeconds=HISTORICAL_SECONDS,
                holderHeight=1000, holderSeconds=HISTORICAL_SECONDS,
                maxAgeNumBlocks=900, maxAgeSeconds=3600, pendingCount=1,
                frontPresent=True, observations=observations)


def pending_context():
    prefix = [dict(height=1000, seconds=HISTORICAL_SECONDS, pending=1, front=True),
              dict(height=1900, seconds=HISTORICAL_SECONDS + 3600, pending=1, front=True),
              dict(height=1901, seconds=HISTORICAL_SECONDS + 3601, pending=1, front=True)]
    return dict(case="pending-restart", evidenceHeight=1000,
                historicalSeconds=HISTORICAL_SECONDS, maxAgeNumBlocks=900, maxAgeSeconds=3600,
                branches=[dict(store="continuing", prefix=deepcopy(prefix)),
                          dict(store="restart", prefix=deepcopy(prefix))],
                continuing=dict(beforeCheck=1, checkAccepted=True, headerLookups=[],
                                validatorLookups=[], beforePrune=1, pruneHeight=1902,
                                pruneSeconds=HISTORICAL_SECONDS + 3602, afterPrune=0,
                                frontAfterPrune=False),
                restart=dict(savedHeight=1901, savedSeconds=HISTORICAL_SECONDS + 3601,
                             loadedHeight=1901, loadedSeconds=HISTORICAL_SECONDS + 3601,
                             beforeStartup=1, afterStartup=0, frontAfterStartup=False))


def marker_context():
    return dict(case="committed-window", evidenceHeight=1000, windowStart=1001,
                checkHeight=1901, installedAt=1001, payloadHeight=1000,
                pendingBeforeInstall=1, pendingAfterInstall=0, markerBeforeInstall=False,
                markerAfterInstall=True, markerAfterReopen=True, reopenedPayloadHeight=1000,
                loadedHeight=1901, loadedSeconds=HISTORICAL_SECONDS + 3601,
                historicalHeaderPresent=False, historicalValidatorRowPresent=False,
                marked=dict(accepted=False, errorType="*types.ErrInvalidEvidence",
                            reason="evidence was already committed", headerLookups=[],
                            validatorLookups=[], pendingAfter=0),
                unmarked=dict(accepted=False, errorType="*errors.errorString",
                              reason="don't have header #1000", headerLookups=[1000],
                              validatorLookups=[], pendingAfter=0))


class EvidenceBoundaryTest(unittest.TestCase):
    def module(self):
        self.assertTrue((CONFORMANCE / "run_comet_evidence.py").is_file(),
                        "native evidence lifecycle consumer is missing")
        return importlib.import_module("run_comet_evidence")

    def test_cold_six_cell_grid_keeps_both_strict_age_boundaries(self):
        self.assertEqual(self.module()._require_cold_context(cold_context()), "cold-grid")

    def test_block_age_alone_cannot_expire_evidence(self):
        reader = self.module()
        for index in (3, 4):
            row = cold_context()
            row["cells"][index].update(accepted=False, result="expired", afterPending=0,
                                       validatorLookups=[])
            with self.subTest(index=index), self.assertRaises(ValueError):
                reader._require_cold_context(row)

    def test_duration_alone_and_exact_duration_cannot_expire_evidence(self):
        reader = self.module()
        for index in (1, 2, 4):
            row = cold_context()
            row["cells"][index].update(accepted=False, result="expired", afterPending=0,
                                       validatorLookups=[])
            with self.subTest(index=index), self.assertRaises(ValueError):
                reader._require_cold_context(row)

    def test_vote_timestamp_cannot_replace_historical_header_time(self):
        reader = self.module()
        for field, value in (("historicalSeconds", 1700000000), ("historicalNanos", 123),
                             ("voteSeconds", HISTORICAL_SECONDS), ("voteNanos", 0)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_cold_context(dict(cold_context(), **{field: value}))
        row = cold_context()
        row["voteTimeAlias"].update(accepted=True, result="accept", afterPending=1,
                                    validatorLookups=[1000])
        with self.assertRaises(ValueError):
            reader._require_cold_context(row)

    def test_cold_cells_have_distinct_empty_stores_and_real_lookup_paths(self):
        reader = self.module()
        for field, value in (("store", "cold-1900-3599"), ("beforePending", 1),
                             ("headerLookups", []), ("validatorLookups", [])):
            row = cold_context()
            row["cells"][1][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_cold_context(row)

    def test_check_evidence_persists_pending_without_adding_gossip_list(self):
        reader = self.module()
        for field, value in (("afterPending", 0), ("afterGossip", True)):
            row = cold_context()
            row["cells"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_cold_context(row)

    def test_context_numbers_and_booleans_preserve_identity(self):
        reader = self.module()
        for field, value in (("evidenceHeight", True), ("maxAgeNumBlocks", 900.0),
                             ("historicalNanos", False)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_cold_context(dict(cold_context(), **{field: value}))
        for field, value in (("accepted", 1), ("beforePending", False), ("afterGossip", 0)):
            row = cold_context()
            row["cells"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_cold_context(row)

    def test_gossip_observes_actual_send_and_old_info_separately(self):
        self.assertEqual(self.module()._require_gossip_context(gossip_context()), "gossip")

    def test_gossip_old_branch_keeps_exact_stock_terms(self):
        reader = self.module()
        for field, value in (("peerHeight", 1900), ("evHeight", 1001),
                             ("maxAgeNumBlocks", 901), ("lastSeconds", 1700000000),
                             ("maxAgeNanos", 3599000000000)):
            row = gossip_context()
            row["observations"][1]["oldInfo"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_gossip_context(row)

    def test_gossip_send_needs_real_channel_evidence_and_eligible_peer(self):
        reader = self.module()
        for field, value in (("peerHeight", 1901), ("branch", "timeout-no-send"),
                             ("channel", 0), ("evidenceCount", 0), ("sendCount", True)):
            row = gossip_context()
            row["observations"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_gossip_context(row)

    def test_service_wait_or_add_peer_return_is_not_a_broadcast_join(self):
        reader = self.module()
        for field, value in (("exitMethod", "BaseService.Wait"),
                             ("broadcastAtStart", 1), ("broadcastAtObservation", 0),
                             ("broadcastAfterQuit", 1)):
            row = gossip_context()
            row["observations"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_gossip_context(row)

    def test_pending_holder_and_restart_have_distinct_same_prefix_branches(self):
        self.assertEqual(self.module()._require_pending_context(pending_context()), "pending-restart")
        reader = self.module()
        row = pending_context()
        row["branches"][1]["store"] = "continuing"
        with self.assertRaises(ValueError):
            reader._require_pending_context(row)
        row = pending_context()
        row["branches"][1]["prefix"][2]["pending"] = 0
        with self.assertRaises(ValueError):
            reader._require_pending_context(row)

    def test_latest_state_is_persisted_before_reopen_and_startup_prunes(self):
        reader = self.module()
        for field, value in (("savedHeight", 1900), ("savedSeconds", HISTORICAL_SECONDS + 3600),
                             ("loadedHeight", 1900), ("beforeStartup", 0), ("afterStartup", 1),
                             ("frontAfterStartup", True)):
            row = pending_context()
            row["restart"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_pending_context(row)

    def test_continuing_pending_survives_equal_threshold_until_own_later_prune(self):
        reader = self.module()
        for field, value in (("beforeCheck", 0), ("checkAccepted", False),
                             ("headerLookups", [1000]), ("beforePrune", 0),
                             ("pruneHeight", 1901), ("afterPrune", 1)):
            row = pending_context()
            row["continuing"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_pending_context(row)

    def test_committed_marker_retains_evidence_height_below_window_after_reopen(self):
        self.assertEqual(self.module()._require_marker_context(marker_context()), "committed-window")
        reader = self.module()
        for field, value in (("payloadHeight", 1001), ("reopenedPayloadHeight", 1001),
                             ("windowStart", 1000), ("pendingAfterInstall", 1),
                             ("markerAfterReopen", False), ("historicalValidatorRowPresent", True)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_marker_context(dict(marker_context(), **{field: value}))

    def test_marked_check_has_typed_committed_refusal_and_zero_actual_lookups(self):
        reader = self.module()
        for field, value in (("accepted", True), ("reason", "don't have header #1000"),
                             ("errorType", "*errors.errorString"), ("headerLookups", [1000]),
                             ("validatorLookups", [1000])):
            row = marker_context()
            row["marked"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_marker_context(row)

    def test_unmarked_control_reaches_the_real_missing_header_before_validators(self):
        reader = self.module()
        for field, value in (("reason", "evidence was already committed"),
                             ("reason", "expired"), ("headerLookups", []),
                             ("validatorLookups", [1000]), ("pendingAfter", 1)):
            row = marker_context()
            row["unmarked"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_marker_context(row)

    def test_contexts_are_closed_and_cannot_silently_drop_or_add_terms(self):
        reader = self.module()
        for factory, check in ((cold_context, reader._require_cold_context),
                               (gossip_context, reader._require_gossip_context),
                               (pending_context, reader._require_pending_context),
                               (marker_context, reader._require_marker_context)):
            row = factory()
            with self.subTest(case=row["case"]), self.assertRaises(ValueError):
                check(dict(row, unrelated=True))
            del row["case"]
            with self.assertRaises(ValueError):
                check(row)

    def profile(self, count=0):
        frames = ["example.org/peer.Send", "github.com/cometbft/cometbft/evidence.(*Reactor).broadcastEvidenceRoutine", "runtime.goexit"]
        return dict(complete=True, inventoryComplete=True, totalGoroutines=2,
                    frameCapacity=32, stackDepths=[4, 5], maxStackDepth=5,
                    emptyStacks=0, saturatedStacks=0, matches=[frames] if count else [], count=count)

    def test_profiles_bind_every_record_and_the_actual_worker_frame(self):
        reader = self.module()
        for count in (0, 1):
            row = self.profile(count)
            self.assertEqual(reader._require_profile(row, count), row)
        row = self.profile(1)
        row["matches"][0][1] = "example.org/another.Worker"
        with self.assertRaises(ValueError):
            reader._require_profile(row, 1)

    def test_profile_inventory_success_does_not_excuse_empty_or_truncated_stacks(self):
        reader = self.module()
        for depth in (0, 32, 33):
            row = self.profile()
            row["stackDepths"][0] = depth
            row["maxStackDepth"] = max(row["stackDepths"])
            row["emptyStacks"], row["saturatedStacks"] = int(depth == 0), int(depth >= 32)
            with self.subTest(depth=depth), self.assertRaises(ValueError):
                reader._require_profile(row, 0)
        row = self.profile()
        row.update(totalGoroutines=0, stackDepths=[], maxStackDepth=0)
        with self.assertRaises(ValueError):
            reader._require_profile(row, 0)

    def test_profile_counts_depths_and_boolean_aliases_are_independently_checked(self):
        reader = self.module()
        changes = ({"totalGoroutines": 3}, {"stackDepths": [True, 5]}, {"maxStackDepth": 4},
                   {"frameCapacity": 32.0}, {"emptyStacks": False}, {"count": False},
                   {"saturatedStacks": False}, {"inventoryComplete": 1}, {"complete": 1})
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                reader._require_profile(dict(self.profile(), **change), 0)

    def test_profile_missing_extra_or_duplicate_worker_records_refuse(self):
        reader = self.module()
        rows = []
        row = self.profile(); row["extra"] = True; rows.append(row)
        row = self.profile(); del row["emptyStacks"]; rows.append(row)
        row = self.profile(1); row["matches"].append(deepcopy(row["matches"][0])); rows.append(row)
        row = self.profile(1); row["matches"][0].append(row["matches"][0][1]); rows.append(row)
        for row in rows:
            with self.subTest(row=row), self.assertRaises(ValueError):
                reader._require_profile(row, row["count"])

    def test_primary_age_control_is_distinct_from_healthy_context(self):
        reader = self.module()
        row = cold_context()
        for index in (2, 3, 4):
            row["cells"][index].update(accepted=False, result="expired", afterPending=0, validatorLookups=[])
        self.assertEqual(reader._require_cold_context(row, source_fault=True), "cold-grid")
        with self.assertRaises(ValueError):
            reader._require_cold_context(row)
        with self.assertRaises(ValueError):
            reader._require_cold_context(cold_context(), source_fault=True)

    def test_full_receipt_interface_requires_original_bytes_and_exact_source_flag(self):
        reader = self.module()
        for raw in ("{}", bytearray(b"{}"), {}, False):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                reader.audit_evidence(raw)
        for source in (0, 1, "healthy", None):
            with self.subTest(source=source), self.assertRaises(ValueError):
                reader.audit_evidence(b"{}", source_fault=source)

    def test_positive_profile_requires_the_simultaneous_sampling_goroutine(self):
        reader = self.module()
        row = self.profile(1)
        row.update(totalGoroutines=1, stackDepths=[1], maxStackDepth=1,
                   matches=[["github.com/cometbft/cometbft/evidence.(*Reactor).broadcastEvidenceRoutine"]])
        with self.assertRaises(ValueError):
            reader._require_profile(row, 1)

    def test_committed_full_error_uses_the_stock_message_type_enum_string(self):
        error = self.module()._EvidenceModel().marker_details()["marked"]["checkResult"]["error"]
        expected = (
            "Invalid evidence: evidence was already committed. Evidence: DuplicateVoteEvidence{"
            "VoteA: Vote{0:D2431CA38735 1000/00/SIGNED_MSG_TYPE_PRECOMMIT(Precommit) AAAAAAAAAAAA "
            "EBA2DC2BFBDD 000000000000 @ 2023-11-14T22:13:20.000000123Z}, "
            "VoteB: Vote{0:D2431CA38735 1000/00/SIGNED_MSG_TYPE_PRECOMMIT(Precommit) BBBBBBBBBBBB "
            "326E2C9C0FD2 000000000000 @ 2023-11-14T22:13:20.000000123Z}}"
        )
        self.assertEqual(error, expected)


if __name__ == "__main__":
    unittest.main()
