// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { LibHashSimple } from "src/layer1/core/libs/LibHashSimple.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibHashParityTest is Test {
    function test_simple_and_optimized_hashes_match() public pure {
        IInbox.CoreState memory core = IInbox.CoreState({
            nextProposalId: 3,
            lastProposalBlockId: 10,
            lastFinalizedProposalId: 1,
            lastFinalizedTimestamp: 77,
            lastCheckpointTimestamp: 70,
            lastFinalizedTransitionHash: bytes32(uint256(1))
        });

        LibBlobs.BlobSlice memory slice0 = LibBlobs.BlobSlice({
            blobHashes: _hashes(bytes32(uint256(100)), bytes32(uint256(101))),
            offset: 8,
            timestamp: 55
        });
        LibBlobs.BlobSlice memory slice1 = LibBlobs.BlobSlice({
            blobHashes: _hashes(bytes32(uint256(102))), offset: 16, timestamp: 56
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 9,
            originBlockHash: bytes32(uint256(3)),
            basefeeSharingPctg: 4,
            sources: _sources(slice0, slice1)
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 2,
            timestamp: 123,
            endOfSubmissionWindowTimestamp: 130,
            proposer: address(0xABCD),
            derivationHash: LibHashSimple.hashDerivation(derivation)
        });

        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 11, blockHash: bytes32(uint256(4)), stateRoot: bytes32(uint256(5))
        });

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: LibHashSimple.hashProposal(proposal),
            parentTransitionHash: bytes32(uint256(6)),
            checkpoint: checkpoint,
            designatedProver: address(0xAAAA),
            actualProver: address(0xBBBB)
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        assertEq(
            LibHashSimple.hashCoreState(core), LibHashOptimized.hashCoreState(core), "core hash"
        );
        assertEq(
            LibHashSimple.hashDerivation(derivation),
            LibHashOptimized.hashDerivation(derivation),
            "derivation hash"
        );
        assertEq(
            LibHashSimple.hashProposal(proposal),
            LibHashOptimized.hashProposal(proposal),
            "proposal hash"
        );
        assertEq(
            LibHashSimple.hashTransition(transition),
            LibHashOptimized.hashTransition(transition),
            "transition hash"
        );
        assertEq(
            LibHashSimple.hashTransitions(transitions),
            LibHashOptimized.hashTransitions(transitions),
            "transitions hash"
        );
    }

    function _sources(
        LibBlobs.BlobSlice memory _a,
        LibBlobs.BlobSlice memory _b
    )
        private
        pure
        returns (IInbox.DerivationSource[] memory arr_)
    {
        arr_ = new IInbox.DerivationSource[](2);
        arr_[0] = IInbox.DerivationSource({ isForcedInclusion: true, blobSlice: _a });
        arr_[1] = IInbox.DerivationSource({ isForcedInclusion: false, blobSlice: _b });
    }

    function _hashes(bytes32 _h1) private pure returns (bytes32[] memory arr_) {
        arr_ = new bytes32[](1);
        arr_[0] = _h1;
    }

    function _hashes(bytes32 _h1, bytes32 _h2) private pure returns (bytes32[] memory arr_) {
        arr_ = new bytes32[](2);
        arr_[0] = _h1;
        arr_[1] = _h2;
    }
}
