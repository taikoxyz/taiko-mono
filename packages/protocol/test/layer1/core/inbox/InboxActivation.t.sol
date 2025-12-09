// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibInboxSetup } from "src/layer1/core/libs/LibInboxSetup.sol";
import { InboxTestBase } from "./InboxTestBase.sol";

/// @notice Tests for Inbox activation and pre-activation behavior
contract InboxActivationTest is InboxTestBase {
    Inbox internal nonActivatedInbox;

    function setUp() public override {
        super.setUp();
        // Deploy a new inbox without activation for these tests
        nonActivatedInbox = _deployNonActivatedInbox();
    }

    function _deployNonActivatedInbox() internal returns (Inbox) {
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
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32(0),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        bytes memory encodedInput = abi.encode(input);
        vm.expectRevert(Inbox.ActivationRequired.selector);
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
        assertEq(nonActivatedInbox.activationTimestamp(), firstActivationTimestamp, "timestamp unchanged");
    }

    function test_getConfig_returnsImmutableConfig() public view {
        IInbox.Config memory cfg = inbox.getConfig();

        // Verify key config values match what was set during construction
        assertEq(cfg.provingWindow, config.provingWindow, "provingWindow mismatch");
        assertEq(cfg.extendedProvingWindow, config.extendedProvingWindow, "extendedProvingWindow mismatch");
        assertEq(cfg.ringBufferSize, config.ringBufferSize, "ringBufferSize mismatch");
        assertEq(cfg.basefeeSharingPctg, config.basefeeSharingPctg, "basefeeSharingPctg mismatch");
        assertEq(cfg.minForcedInclusionCount, config.minForcedInclusionCount, "minForcedInclusionCount mismatch");
        assertEq(cfg.forcedInclusionFeeInGwei, config.forcedInclusionFeeInGwei, "forcedInclusionFeeInGwei mismatch");
        assertEq(cfg.minProposalsToFinalize, config.minProposalsToFinalize, "minProposalsToFinalize mismatch");
        assertEq(cfg.codec, config.codec, "codec mismatch");
        assertEq(cfg.proofVerifier, config.proofVerifier, "proofVerifier mismatch");
        assertEq(cfg.proposerChecker, config.proposerChecker, "proposerChecker mismatch");
        assertEq(cfg.signalService, config.signalService, "signalService mismatch");
    }
}

/// @notice Tests for LibInboxSetup config validation
contract LibInboxSetupConfigValidationTest is InboxTestBase {
    function test_validateConfig_RevertWhen_CodecZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.codec = address(0);

        vm.expectRevert(LibInboxSetup.CodecZero.selector);
        new Inbox(cfg);
    }

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

    function test_validateConfig_RevertWhen_SignalServiceZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.signalService = address(0);

        vm.expectRevert(LibInboxSetup.SignalServiceZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProvingWindowZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.provingWindow = 0;

        vm.expectRevert(LibInboxSetup.ProvingWindowZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ExtendedWindowTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.extendedProvingWindow = cfg.provingWindow; // Must be > provingWindow

        vm.expectRevert(LibInboxSetup.ExtendedWindowTooSmall.selector);
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

    function test_validateConfig_RevertWhen_MinProposalsToFinalizeTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.minProposalsToFinalize = 0;

        vm.expectRevert(LibInboxSetup.MinProposalsToFinalizeTooSmall.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_MinProposalsToFinalizeTooBig() public {
        IInbox.Config memory cfg = _buildConfig();
        // minProposalsToFinalize must be < ringBufferSize - 1
        cfg.minProposalsToFinalize = uint8(cfg.ringBufferSize - 1);

        vm.expectRevert(LibInboxSetup.MinProposalsToFinalizeTooBig.selector);
        new Inbox(cfg);
    }
}
