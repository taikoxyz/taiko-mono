// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxGridExamplesTest
/// @notice Replays nine of the Lean model's grid-landing examples (`Etna.Design.Examples`) against
/// `land`; each test names the example it replays. Two grid examples are not replayed here: one
/// makes no landing, and `EtnaInboxLandTest` covers the foreign-generation rejection.
/// @dev The Lean states are this suite's chain: `initial` is the state after `setUp` (c = 0,
/// queue head 0 and tail 3), and `afterOne`, `afterTwo` and `afterThree` follow the landings
/// (0, 6], (0, 12] and (0, 18], each proved from p = 0 with the honest grid leaves and
/// snapshot 4. Lean's landing environment is the base's reference block 10, its blobs and a
/// verifier that accepts the statement it is given.
contract EtnaInboxGridExamplesTest is EtnaLandTestBase {
    /// @dev `cutLeaf(6)` and `cutLeaf(12)` of the committed chain: `cuts.table[6].leaf` and
    /// `cuts.table[12].leaf` in `testdata/etna_vectors/vectors.json`.
    bytes32 private constant _LEAF_6 =
        0x7b344c9699a4702dfbf7c0c72c1b6b4f8717e764c2d9157d55f4c59c56e3f430;
    bytes32 private constant _LEAF_12 =
        0x061f4a7bd1a37f73423c186b40468e6c37353882bb818a20ee34c07dfe30469b;

    /// @dev The generation-0 cut hashes of (0, 6], (0, 12] and (0, 18]: the `g0_p0_h6`,
    /// `g0_p0_h12` and `g0_p0_h18` vectors.
    bytes32 private constant _CUT_HASH_0_6 =
        0xcf8e3c664c50dae3ca433e951161604725515156d44722b20b12c56e002d3715;
    bytes32 private constant _CUT_HASH_0_12 =
        0xae874ed6014bf59ae91121c7bd35bd0a6afc886c3b54f476c1b96dac5a2d72fb;
    bytes32 private constant _CUT_HASH_0_18 =
        0xc30fe19d5489610933a6f27e72792d7cbbd2934c877d5692784dafaabf75505c;

    /// @dev Lean `grid_leaf_lists`: the honest leaves of (0, h] are the cut leaves at the grid
    /// points strictly inside it, none for h = 6. From c = 0 `land` accepts each list and binds
    /// it into the vector cut hash.
    function test_land_ExampleGridLeafLists() external {
        assertEq(
            _leaf(6),
            keccak256(
                abi.encode(uint256(6), bytes32(uint256(106)), bytes32(uint256(206)), uint256(1))
            ),
            "cutLeaf 6 preimage"
        );
        assertEq(
            _leaf(12),
            keccak256(
                abi.encode(uint256(12), bytes32(uint256(112)), bytes32(uint256(212)), uint256(2))
            ),
            "cutLeaf 12 preimage"
        );
        assertEq(_leaf(6), _LEAF_6, "cutLeaf 6 vector");
        assertEq(_leaf(12), _LEAF_12, "cutLeaf 12 vector");

        bytes32[] memory one = _leaves(0, 6);
        bytes32[] memory two = _leaves(0, 12);
        bytes32[] memory full = _leaves(0, 18);
        assertEq(one.length, 0, "(0, 6]: no leaf");
        assertEq(two.length, 1, "(0, 12]: one leaf");
        assertEq(two[0], _LEAF_6, "(0, 12]: the leaf at 6");
        assertEq(full.length, 2, "(0, 18]: two leaves");
        assertEq(full[0], _LEAF_6, "(0, 18]: the leaf at 6");
        assertEq(full[1], _LEAF_12, "(0, 18]: the leaf at 12");

        uint256 initial = vm.snapshotState();
        _landFromInitial(6, one, _CUT_HASH_0_6);
        vm.revertToState(initial);
        _landFromInitial(12, two, _CUT_HASH_0_12);
        vm.revertToState(initial);
        _landFromInitial(18, full, _CUT_HASH_0_18);
    }

    /// @dev Lean `overlapping_landings_from_one_origin`: (0, 6], (0, 12] and (0, 18] land in
    /// sequence, all proved from p = 0; each settles the segment above the previous checkpoint
    /// and leaves `landings(0)` untouched.
    function test_land_ExampleOverlappingLandingsFromOneOrigin() external {
        for (uint256 h = K; h <= 3 * K; h += K) {
            assertEq(_inbox().lastCheckpoint().height, h - K, "c is the previous landing");
            // `_land` expects `Landed(0, h - 6, h, ...)` and a statement over `landings(0)`.
            _land(0, h);
            _assertCheckpoint(h, bytes32(100 + h));
            _assertLanding(h, _record(h - K, h));
            _assertQueue(h / K, LEAN_FORCED_INCLUSIONS);
            assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot");
        }
        _assertLanding(0, _record(0, 0));
    }

    /// @dev Lean `same_transaction_lands_at_any_grid_frontier`: one (0, 18] calldata, built
    /// before any landing, lands whether c is 0, 6 or 12. The verifier receives the same
    /// statement from each frontier and every landing ends in the same checkpoint, queue head,
    /// snapshot and record hashes; the record's parent is the frontier it settled on.
    function test_land_ExampleSameTransactionLandsAtEveryGridFrontier() external {
        IEtnaInbox.LandInput memory input = _input(0, 18);
        bytes32[] memory leaves = _leaves(0, 18);
        bytes memory data = abi.encodeCall(IEtnaInbox.land, (input, leaves, PROOF));
        bytes32 cutHash = _cutHash(input, leaves);
        bytes32 statement = _statement(input, _inbox().landings(0), cutHash);
        uint256 initial = vm.snapshotState();

        for (uint256 c; c <= 2 * K; c += K) {
            vm.revertToState(initial);
            for (uint256 h = K; h <= c; h += K) {
                _land(0, h);
            }
            assertEq(_inbox().lastCheckpoint().height, c, "frontier");
            // The proof is valid only for the statement computed before any landing.
            landVerifier.setExpectedStatementHash(statement);

            vm.blobhashes(blobHashes);
            vm.expectCall(
                address(landVerifier),
                abi.encodeCall(IProofVerifier.verifyProof, (0, statement, PROOF))
            );
            vm.expectEmit(inboxProxy);
            emit IEtnaInbox.Landed(0, c, 18, cutHash, LEAN_SNAPSHOT, 1);
            vm.prank(Bob);
            (bool ok, bytes memory reason) = inboxProxy.call(data);
            assertTrue(ok, string(reason));

            _assertCheckpoint(18, bytes32(uint256(118)));
            _assertLanding(18, _record(c, 18));
            _assertQueue(3, LEAN_FORCED_INCLUSIONS);
            assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot");
            _assertSignal(18);
        }
    }

    /// @dev Lean `landing_records_actual_edges`: after (0, 6], (0, 12] and (0, 18] from p = 0
    /// the records hold the settled edges (12, 18), (6, 12), (0, 6) and the genesis (0, 0), never
    /// the proof origin. A record is three words with no state root; the state root goes only to
    /// the SignalService.
    function test_land_ExampleLandingRecordsActualEdges() external {
        _land(0, 6);
        _land(0, 12);
        _land(0, 18);

        _assertLanding(18, _record(12, 18));
        _assertLanding(12, _record(6, 12));
        _assertLanding(6, _record(0, 6));
        _assertLanding(0, _record(0, 0));
        for (uint256 h = K; h <= 3 * K; h += K) {
            _assertSignal(h);
        }
        _assertCheckpoint(18, bytes32(uint256(118)));
        _assertQueue(3, LEAN_FORCED_INCLUSIONS);
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot");
        assertEq(uint256(_inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)), LEAN_SNAPSHOT, "slot 284");
    }

    /// @dev Lean `settled_original_target_rejected`: once 18 is settled the original (0, 18]
    /// transaction is rejected.
    function test_land_ExampleSettledTargetRejected() external {
        _land(0, 6);
        _land(0, 12);
        _land(0, 18);
        _expectLandRevert(_input(0, 18), _leaves(0, 18), IEtnaInbox.AlreadySettled.selector);
    }

    /// @dev Lean `corrupt_frontier_leaf_rejected`: at c = 12 the leaf at 12 must be cutLeaf(12)
    /// over `landings(12)`; one with Comet hash 999, or the right cut hashed with height 13, is
    /// rejected while the verifier rejects everything, so before the proof.
    function test_land_ExampleCorruptFrontierLeafRejectedBeforeProof() external {
        _land(0, 6);
        _land(0, 12);
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(0, 18);
        bytes32[] memory leaves = _leaves(0, 18);
        (bytes32 el, bytes32 comet, uint256 head) = _cut(12);

        leaves[1] = _leafOf(12, el, bytes32(uint256(999)), head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[1] = _leafOf(13, el, comet, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);

        // The honest list passes the leaf check and reaches the verifier.
        _expectLandRevert(input, _leaves(0, 18), MockLandProofVerifier.ProofRejected.selector);
    }

    /// @dev Lean `corrupt_inner_leaf_fails_proof`: at c = 12 a leaf at 6 with Comet hash 999
    /// passes every check before the proof, so the verifier is called, with a statement whose
    /// cutHash covers the corrupt leaf, and only a verifier accepting the honest statement
    /// rejects it.
    function test_land_ExampleCorruptInnerLeafFailsOnlyTheProof() external {
        _land(0, 6);
        _land(0, 12);
        IEtnaInbox.LandInput memory input = _input(0, 18);
        bytes32[] memory honest = _leaves(0, 18);
        bytes32[] memory corrupt = _leaves(0, 18);
        (bytes32 el,, uint256 head) = _cut(6);
        corrupt[0] = _leafOf(6, el, bytes32(uint256(999)), head);

        IEtnaInbox.Landing memory origin = _inbox().landings(0);
        bytes32 honestStatement = _statement(input, origin, _cutHash(input, honest));
        bytes32 corruptStatement = _statement(input, origin, _cutHash(input, corrupt));
        assertNotEq(corruptStatement, honestStatement, "the corrupt leaf changes the statement");
        landVerifier.setExpectedStatementHash(honestStatement);

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, corruptStatement, PROOF))
        );
        _expectLandRevert(input, corrupt, MockLandProofVerifier.ProofRejected.selector);

        assertEq(_land(input, honest), honestStatement, "the honest list lands");
        _assertLanding(18, _record(12, 18));
    }

    /// @dev Lean `wrong_leaf_count_and_off_grid_rejected`: at c = 12, (0, 18] with one leaf or
    /// with a third leaf at 18 is rejected; at c = 6, (0, 12]'s inputs and leaves with h = 13 are
    /// off the grid.
    function test_land_ExampleWrongLeafCountAndOffGridRejected() external {
        _land(0, 6);
        IEtnaInbox.LandInput memory offGrid = _input(0, 12);
        offGrid.lastHeight = 13;
        _expectLandRevert(offGrid, _leaves(0, 12), IEtnaInbox.OffGrid.selector);

        _land(0, 12);
        IEtnaInbox.LandInput memory input = _input(0, 18);
        bytes32[] memory one = new bytes32[](1);
        one[0] = _leaf(6);
        _expectLandRevert(input, one, IEtnaInbox.LeafCountMismatch.selector);
        bytes32[] memory three = new bytes32[](3);
        (three[0], three[1], three[2]) = (_leaf(6), _leaf(12), _leaf(18));
        _expectLandRevert(input, three, IEtnaInbox.LeafCountMismatch.selector);

        _assertCheckpoint(12, bytes32(uint256(112)));
    }

    /// @dev Lean `snapshot_stored_as_proven`: `land` puts no bound on the snapshot, so from
    /// `afterTwo`, which holds snapshot 4, (0, 18] proving snapshot 2 lands and stores 2. The proof
    /// is over snapshot 2, and no on-chain maximum keeps the larger stored value.
    function test_land_ExampleSnapshotStoredAsProven() external {
        _land(0, 6);
        _land(0, 12);
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "afterTwo holds snapshot 4");

        IEtnaInbox.LandInput memory input = _input(0, 18);
        input.activeCommitteeSnapshot = 2;
        bytes32[] memory leaves = _leaves(0, 18);
        IEtnaInbox.Landing memory origin = _inbox().landings(0);
        bytes32 statement = _statement(input, origin, _cutHash(input, leaves));
        assertNotEq(
            statement,
            _statement(_input(0, 18), origin, _cutHash(input, leaves)),
            "the statement binds the snapshot"
        );
        landVerifier.setExpectedStatementHash(statement);

        assertEq(_land(input, leaves), statement, "the proof is over snapshot 2");
        assertEq(_inbox().activeCommitteeSnapshot(), 2, "stored as proven");
        assertEq(uint256(_inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)), 2, "slot 284");
        _assertCheckpoint(18, bytes32(uint256(118)));
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev From c = 0, lands (0, `_h`] with `_leafList`, whose cut hash must be `_cutHashValue`.
    function _landFromInitial(
        uint256 _h,
        bytes32[] memory _leafList,
        bytes32 _cutHashValue
    )
        private
    {
        assertEq(_inbox().lastCheckpoint().height, 0, "from c = 0");
        IEtnaInbox.LandInput memory input = _input(0, _h);
        assertEq(_cutHash(input, _leafList), _cutHashValue, "cut hash vector");
        _land(input, _leafList);
        _assertCheckpoint(_h, bytes32(100 + _h));
        _assertLanding(_h, _record(0, _h));
    }

    /// @dev The generation-0 record of the edge (`_parent`, `_x`]: the committed chain's hashes
    /// and queue head at `_x`.
    function _record(uint256 _parent, uint256 _x) private pure returns (IEtnaInbox.Landing memory) {
        (bytes32 el, bytes32 comet, uint256 head) = _cut(_x);
        return IEtnaInbox.Landing({
            parentHeight: uint48(_parent),
            generation: 0,
            head: uint48(head),
            elHash: el,
            cometHash: comet
        });
    }

    /// @dev Checks the SignalService checkpoint `(_h, 100 + _h, 300 + _h)`.
    function _assertSignal(uint256 _h) private view {
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(uint48(_h));
        assertEq(saved.blockNumber, _h, "signal height");
        assertEq(saved.blockHash, bytes32(100 + _h), "signal block hash");
        assertEq(saved.stateRoot, _stateRoot(_h), "signal state root");
    }
}
