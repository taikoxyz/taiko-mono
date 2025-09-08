// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { InboxOptimized4 } from "contracts/layer1/shasta/impl/InboxOptimized4.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";

/// @title HashBenchmarkContract
/// @notice Contract to benchmark gas improvements in hash functions
contract HashBenchmarkContract {
    Inbox public originalInbox;
    InboxOptimized4 public optimizedInbox;

    event GasBenchmarkResult(
        string functionName,
        uint256 originalGas,
        uint256 optimizedGas,
        uint256 gasSaved,
        uint256 percentSaved
    );

    constructor() {
        // Create sample configuration
        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0x123),
            checkpointManager: address(0x456),
            proofVerifier: address(0x789),
            proposerChecker: address(0xabc),
            provingWindow: 3600,
            extendedProvingWindow: 7200,
            maxFinalizationCount: 10,
            finalizationGracePeriod: 1800,
            ringBufferSize: 1024,
            basefeeSharingPctg: 50,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 300,
            forcedInclusionFeeInGwei: 10
        });

        originalInbox = new Inbox(config);
        optimizedInbox = new InboxOptimized4(config);
    }

    function benchmarkHashTransition() external {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: keccak256("proposal1"),
            parentTransitionHash: keccak256("parent1"),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 12345,
                blockHash: keccak256("block1"),
                stateRoot: keccak256("state1")
            }),
            designatedProver: address(0x111),
            actualProver: address(0x222)
        });

        uint256 gasBefore = gasleft();
        originalInbox.hashTransition(transition);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        optimizedInbox.hashTransition(transition);
        uint256 gasOptimized = gasBefore - gasleft();

        _emitGasComparison("hashTransition", gasOriginal, gasOptimized);
    }

    function benchmarkHashCheckpoint() external {
        ICheckpointManager.Checkpoint memory checkpoint = ICheckpointManager.Checkpoint({
            blockNumber: 12345,
            blockHash: keccak256("block1"),
            stateRoot: keccak256("state1")
        });

        uint256 gasBefore = gasleft();
        originalInbox.hashCheckpoint(checkpoint);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        optimizedInbox.hashCheckpoint(checkpoint);
        uint256 gasOptimized = gasBefore - gasleft();

        _emitGasComparison("hashCheckpoint", gasOriginal, gasOptimized);
    }

    function benchmarkHashCoreState() external {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 99,
            lastFinalizedTransitionHash: keccak256("lastTx"),
            bondInstructionsHash: keccak256("bonds")
        });

        uint256 gasBefore = gasleft();
        originalInbox.hashCoreState(coreState);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        optimizedInbox.hashCoreState(coreState);
        uint256 gasOptimized = gasBefore - gasleft();

        _emitGasComparison("hashCoreState", gasOriginal, gasOptimized);
    }

    function benchmarkHashProposal() external {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 42,
            timestamp: 1700000000,
            lookaheadSlotTimestamp: 1700000012,
            proposer: address(0x333),
            coreStateHash: keccak256("coreState"),
            derivationHash: keccak256("derivation")
        });

        uint256 gasBefore = gasleft();
        originalInbox.hashProposal(proposal);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        optimizedInbox.hashProposal(proposal);
        uint256 gasOptimized = gasBefore - gasleft();

        _emitGasComparison("hashProposal", gasOriginal, gasOptimized);
    }

    function benchmarkHashDerivation() external {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 12340,
            originBlockHash: keccak256("origin"),
            isForcedInclusion: false,
            basefeeSharingPctg: 50,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 100,
                timestamp: 1700000000
            })
        });

        uint256 gasBefore = gasleft();
        originalInbox.hashDerivation(derivation);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        optimizedInbox.hashDerivation(derivation);
        uint256 gasOptimized = gasBefore - gasleft();

        _emitGasComparison("hashDerivation", gasOriginal, gasOptimized);
    }

    function benchmarkAllFunctions() external {
        this.benchmarkHashTransition();
        this.benchmarkHashCheckpoint();
        this.benchmarkHashCoreState();
        this.benchmarkHashProposal();
        this.benchmarkHashDerivation();
    }

    function _emitGasComparison(
        string memory functionName,
        uint256 gasOriginal,
        uint256 gasOptimized
    ) internal {
        uint256 gasSaved = gasOriginal > gasOptimized ? gasOriginal - gasOptimized : 0;
        uint256 percentSaved = gasOriginal > 0 ? (gasSaved * 100) / gasOriginal : 0;

        emit GasBenchmarkResult(functionName, gasOriginal, gasOptimized, gasSaved, percentSaved);
    }

    function testHashFunctionCorrectness() external view returns (bool) {
        // Test data
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: keccak256("proposal1"),
            parentTransitionHash: keccak256("parent1"),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 12345,
                blockHash: keccak256("block1"),
                stateRoot: keccak256("state1")
            }),
            designatedProver: address(0x111),
            actualProver: address(0x222)
        });

        ICheckpointManager.Checkpoint memory checkpoint = ICheckpointManager.Checkpoint({
            blockNumber: 12345,
            blockHash: keccak256("block1"),
            stateRoot: keccak256("state1")
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 99,
            lastFinalizedTransitionHash: keccak256("lastTx"),
            bondInstructionsHash: keccak256("bonds")
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 42,
            timestamp: 1700000000,
            lookaheadSlotTimestamp: 1700000012,
            proposer: address(0x333),
            coreStateHash: keccak256("coreState"),
            derivationHash: keccak256("derivation")
        });

        // Verify all hash functions produce identical results
        require(originalInbox.hashTransition(transition) == optimizedInbox.hashTransition(transition), "hashTransition mismatch");
        require(originalInbox.hashCheckpoint(checkpoint) == optimizedInbox.hashCheckpoint(checkpoint), "hashCheckpoint mismatch");
        require(originalInbox.hashCoreState(coreState) == optimizedInbox.hashCoreState(coreState), "hashCoreState mismatch");
        require(originalInbox.hashProposal(proposal) == optimizedInbox.hashProposal(proposal), "hashProposal mismatch");

        return true;
    }
}