// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibInboxSetup } from "src/layer1/core/libs/LibInboxSetup.sol";

/// @notice Tests for Inbox activation and pre-activation behavior
contract InboxActivationTest is InboxTestBase {
    Inbox internal nonActivatedInbox;

    function setUp() public override {
        super.setUp();
        // Deploy a new inbox without activation for these tests
        nonActivatedInbox = _deployNonActivatedInbox();
    }

    function _deployNonActivatedInbox() private returns (Inbox) {
        address impl = address(new Inbox(config));
        return Inbox(address(new ERC1967Proxy(impl, abi.encodeCall(Inbox.init, (address(this))))));
    }

    function test_propose_RevertWhen_NotActivated() public {
        _setBlobHashes(1);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ActivationRequired.selector);
        vm.prank(proposer);
        nonActivatedInbox.propose(bytes(""), encodedInput);
    }

    function test_prove_RevertWhen_NotActivated() public {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("checkpoint")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: bytes32(0),
                lastProposalHash: bytes32(uint256(123)),
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: bytes32(uint256(1)),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        nonActivatedInbox.prove(encodedInput, bytes("proof"));
    }

    function test_activate_RevertWhen_InvalidLastPacayaBlockHash() public {
        vm.expectRevert(LibInboxSetup.InvalidLastPacayaBlockHash.selector);
        nonActivatedInbox.activate(bytes32(0));
    }

    function test_activate_RevertWhen_ActivationPeriodExpired() public {
        // First activation
        nonActivatedInbox.activate(bytes32(uint256(1)));

        // Warp past activation window (2 hours)
        vm.warp(block.timestamp + 2 hours + 1);

        // Second activation should fail
        vm.expectRevert(LibInboxSetup.ActivationPeriodExpired.selector);
        nonActivatedInbox.activate(bytes32(uint256(2)));
    }

    function test_activate_allowsReactivationWithinWindow() public {
        // First activation
        nonActivatedInbox.activate(bytes32(uint256(1)));
        uint48 firstActivationTimestamp = nonActivatedInbox.activationTimestamp();

        // Warp within activation window
        vm.warp(block.timestamp + 1 hours);

        // Second activation should succeed
        nonActivatedInbox.activate(bytes32(uint256(2)));

        // Activation timestamp should remain the same
        assertEq(
            nonActivatedInbox.activationTimestamp(), firstActivationTimestamp, "timestamp unchanged"
        );
    }

    function test_activate_reactivation_resetsProposalHistory_keepsForcedInclusions() public {
        nonActivatedInbox.activate(bytes32(uint256(1)));

        // Propose once so proposal hash slot 1 is populated.
        _setBlobHashes(1);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encoded = ICodec(address(nonActivatedInbox)).encodeProposeInput(input);
        vm.prank(proposer);
        nonActivatedInbox.propose(bytes(""), encoded);
        bytes32 proposalHashBefore = nonActivatedInbox.getProposalHash(1);

        // Queue a forced inclusion and record state.
        _setBlobHashes(1);
        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });
        uint64 feeInGwei = nonActivatedInbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        nonActivatedInbox.saveForcedInclusion{ value: uint256(feeInGwei) * 1 gwei }(blobRef);

        (uint48 headBefore, uint48 tailBefore) = nonActivatedInbox.getForcedInclusionState();

        // Reactivate within window
        vm.warp(block.timestamp + 1 hours);
        nonActivatedInbox.activate(bytes32(uint256(2)));

        // Forced inclusions preserved
        (uint48 headAfter, uint48 tailAfter) = nonActivatedInbox.getForcedInclusionState();
        assertEq(headAfter, headBefore, "forced inclusion head");
        assertEq(tailAfter, tailBefore, "forced inclusion tail");

        // Proposal history invalidated via core state reset
        IInbox.CoreState memory state = nonActivatedInbox.getCoreState();
        assertEq(state.nextProposalId, 1, "nextProposalId reset");
        assertEq(state.lastFinalizedProposalId, 0, "finalized reset");
        assertEq(state.lastProposalBlockId, 1, "lastProposalBlockId reset");

        // Ring buffer storage is not cleared on reactivation; old entries are
        // logically invalidated by the core state reset.
        assertEq(nonActivatedInbox.getProposalHash(1), proposalHashBefore, "proposal hash retained");
    }

    function test_getConfig_returnsImmutableConfig() public view {
        IInbox.Config memory cfg = inbox.getConfig();

        // Verify key config values match what was set during construction
        assertEq(cfg.provingWindow, config.provingWindow, "provingWindow mismatch");
        assertEq(cfg.ringBufferSize, config.ringBufferSize, "ringBufferSize mismatch");
        assertEq(cfg.basefeeSharingPctg, config.basefeeSharingPctg, "basefeeSharingPctg mismatch");
        assertEq(
            cfg.minForcedInclusionCount,
            config.minForcedInclusionCount,
            "minForcedInclusionCount mismatch"
        );
        assertEq(
            cfg.forcedInclusionFeeInGwei,
            config.forcedInclusionFeeInGwei,
            "forcedInclusionFeeInGwei mismatch"
        );
        assertEq(cfg.proofVerifier, config.proofVerifier, "proofVerifier mismatch");
        assertEq(cfg.proposerChecker, config.proposerChecker, "proposerChecker mismatch");
        assertEq(cfg.signalService, config.signalService, "signalService mismatch");
        assertEq(cfg.bondToken, config.bondToken, "bondToken mismatch");
        assertEq(cfg.minBond, config.minBond, "minBond mismatch");
        assertEq(cfg.livenessBond, config.livenessBond, "livenessBond mismatch");
        assertEq(cfg.withdrawalDelay, config.withdrawalDelay, "withdrawalDelay mismatch");
    }
}

/// @notice Tests for LibInboxSetup config validation
contract LibInboxSetupConfigValidationTest is InboxTestBase {
    function test_validateConfig_RevertWhen_ProofVerifierZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.proofVerifier = address(0);

        vm.expectRevert(LibInboxSetup.ProofVerifierZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProposerCheckerZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.proposerChecker = address(0);

        vm.expectRevert(LibInboxSetup.ProposerCheckerZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProverAuctionZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.proverAuction = address(0);

        vm.expectRevert(LibInboxSetup.ProverAuctionZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_SignalServiceZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.signalService = address(0);

        vm.expectRevert(LibInboxSetup.SignalServiceZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_BondTokenZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.bondToken = address(0);

        vm.expectRevert(LibInboxSetup.BondTokenZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProvingWindowZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.provingWindow = 0;

        vm.expectRevert(LibInboxSetup.ProvingWindowZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_RingBufferSizeTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.ringBufferSize = 1; // Must be > 1

        vm.expectRevert(LibInboxSetup.RingBufferSizeTooSmall.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_BasefeeSharingPctgTooLarge() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.basefeeSharingPctg = 101; // Must be <= 100

        vm.expectRevert(LibInboxSetup.BasefeeSharingPctgTooLarge.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_MinForcedInclusionCountZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.minForcedInclusionCount = 0;

        vm.expectRevert(LibInboxSetup.MinForcedInclusionCountZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_MinForcedInclusionCountTooLarge() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.minForcedInclusionCount = uint256(type(uint8).max) + 1;

        vm.expectRevert(LibInboxSetup.MinForcedInclusionCountTooLarge.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ForcedInclusionFeeInGweiZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.forcedInclusionFeeInGwei = 0;

        vm.expectRevert(LibInboxSetup.ForcedInclusionFeeInGweiZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ForcedInclusionFeeDoubleThresholdZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.forcedInclusionFeeDoubleThreshold = 0;

        vm.expectRevert(LibInboxSetup.ForcedInclusionFeeDoubleThresholdZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_PermissionlessInclusionMultiplierTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.permissionlessInclusionMultiplier = 1; // Must be > 1

        vm.expectRevert(LibInboxSetup.PermissionlessInclusionMultiplierTooSmall.selector);
        new Inbox(cfg);
    }
}
