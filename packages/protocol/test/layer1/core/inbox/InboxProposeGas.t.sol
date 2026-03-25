// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";

/// @notice Gas benchmarks for propose() with pre-filled ring buffer slots.
/// @dev Uses MainnetInbox (transient storage reentrancy lock) to match production.
///      Ring buffer is pre-filled with non-zero proposal hashes to measure real
///      steady-state SSTORE cost (overwriting non-zero → non-zero).
contract InboxProposeGasTest is InboxTestBase {
    /// @dev Use a realistic ring buffer size matching MainnetInbox production config.
    uint48 private constant RING_BUFFER_SIZE = 100;

    /// @dev Number of proposals to pre-fill. Must be < RING_BUFFER_SIZE to leave capacity.
    uint48 private constant PREFILL_COUNT = 50;

    function _buildConfig() internal override returns (IInbox.Config memory) {
        IInbox.Config memory cfg = super._buildConfig();
        cfg.ringBufferSize = RING_BUFFER_SIZE;
        // Match MainnetInbox production: minBond = 0, livenessBond = 0
        cfg.minBond = 0;
        cfg.livenessBond = 0;
        cfg.basefeeSharingPctg = 75;
        cfg.forcedInclusionDelay = 576 seconds;
        cfg.forcedInclusionFeeInGwei = 1_000_000;
        cfg.forcedInclusionFeeDoubleThreshold = 50;
        cfg.permissionlessInclusionMultiplier = 160;
        cfg.provingWindow = 4 hours;
        cfg.permissionlessProvingDelay = 5 days;
        cfg.maxProofSubmissionDelay = 3 minutes;
        return cfg;
    }

    /// @dev Deploy MainnetInbox instead of plain Inbox to match production behavior.
    function _deployInbox() internal override returns (Inbox) {
        address impl = address(
            new MainnetInbox(
                address(verifier),
                address(proposerChecker),
                address(proverWhitelistContract),
                address(signalService),
                address(bondToken)
            )
        );
        return _deployProxy(impl);
    }

    function setUp() public override {
        super.setUp();
        _prefillRingBuffer();
    }

    /// @dev Pre-fill ring buffer slots with non-zero proposal hashes and finalize them
    ///      so they don't consume capacity but the storage slots contain non-zero values.
    ///      This simulates a mature system where the ring buffer wraps around.
    function _prefillRingBuffer() internal {
        _setBlobHashes(1);

        // Propose PREFILL_COUNT proposals
        IInbox.Transition[] memory transitions = new IInbox.Transition[](PREFILL_COUNT);
        uint48 firstProposalId;

        for (uint48 i; i < PREFILL_COUNT; ++i) {
            _advanceBlock();
            ProposedEvent memory payload = _proposeAndDecode(_defaultProposeInput());
            if (i == 0) firstProposalId = payload.id;

            transitions[i] = _transitionFor(
                payload, uint48(block.timestamp), keccak256(abi.encode("blockHash", i))
            );
        }

        // Prove/finalize all proposals so capacity is freed
        uint256 lastProposalId = firstProposalId + PREFILL_COUNT - 1;
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: firstProposalId,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("prefillStateRoot"),
                transitions: transitions
            })
        });
        _prove(proveInput);

        // Now all PREFILL_COUNT ring buffer slots have non-zero hashes,
        // and capacity is restored since they are finalized.
        _advanceBlock();
    }

    // ---------------------------------------------------------------
    // Gas Benchmarks
    // ---------------------------------------------------------------

    /// @notice Baseline: standard propose with 1 blob, no forced inclusions.
    /// This is the most common production path.
    function test_propose_gas_baseline() public {
        _setBlobHashes(1);
        _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_gas_baseline");
    }

    /// @notice Propose with 3 blobs, no forced inclusions.
    function test_propose_gas_3blobs() public {
        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.blobReference = LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 3, offset: 0 });
        _proposeAndDecodeWithGas(input, "propose_gas_3blobs");
    }

    /// @notice Propose with 1 forced inclusion (due).
    function test_propose_gas_1_forced_inclusion() public {
        // First we need a prior proposal for saveForcedInclusion to work
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();

        // Save a forced inclusion
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(forcedRef);

        // Wait for it to become due
        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        _advanceBlock();

        _setBlobHashes(1);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = 1;
        _proposeAndDecodeWithGas(input, "propose_gas_1_forced_inclusion");
    }

    /// @notice Second propose after the first, measuring wrap-around cost.
    function test_propose_gas_second_propose() public {
        _setBlobHashes(1);
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_gas_second_propose");
    }

    /// @notice proposeDefault(): zero parameters, 1 blob, no forced inclusions.
    function test_proposeSimple_gas_baseline() public {
        _setBlobHashes(1);
        // Warm up the proxy's implementation slot (same as _proposeAndDecodeWithGas does
        // via codec.encodeProposeInput which is an external call to the inbox proxy).
        inbox.getConfig();
        vm.startPrank(proposer);
        vm.startSnapshotGas("shasta-propose", "proposeDefault_gas_baseline");
        inbox.proposeDefault();
        vm.stopSnapshotGas();
        vm.stopPrank();
    }

    /// @notice proposeCompact(): explicit params, 1 blob, no forced inclusions.
    function test_proposeCompact_gas_baseline() public {
        _setBlobHashes(1);
        inbox.getConfig(); // warm up proxy
        vm.startPrank(proposer);
        vm.startSnapshotGas("shasta-propose", "proposeCompact_gas_baseline");
        inbox.proposeCompact(0, 1, 0, 0);
        vm.stopSnapshotGas();
        vm.stopPrank();
    }

    /// @notice proposeCompact(): 3 blobs, no forced inclusions.
    function test_proposeCompact_gas_3blobs() public {
        _setBlobHashes(3);
        inbox.getConfig(); // warm up proxy
        vm.startPrank(proposer);
        vm.startSnapshotGas("shasta-propose", "proposeCompact_gas_3blobs");
        inbox.proposeCompact(0, 3, 0, 0);
        vm.stopSnapshotGas();
        vm.stopPrank();
    }

    /// @notice proposeCompact(): 1 forced inclusion.
    function test_proposeCompact_gas_1_forced_inclusion() public {
        // First we need a prior proposal for saveForcedInclusion to work
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();

        // Save a forced inclusion
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(forcedRef);

        // Wait for it to become due
        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        _advanceBlock();

        _setBlobHashes(1);
        inbox.getConfig(); // warm up proxy
        vm.startPrank(proposer);
        vm.startSnapshotGas("shasta-propose", "proposeCompact_gas_1_forced_inclusion");
        inbox.proposeCompact(0, 1, 0, 1);
        vm.stopSnapshotGas();
        vm.stopPrank();
    }
}
