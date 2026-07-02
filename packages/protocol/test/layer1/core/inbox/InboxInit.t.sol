// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Tests for Inbox initialization and pre-initialization behavior
contract InboxInitTest is InboxTestBase {
    Inbox internal uninitializedInbox;

    function setUp() public override {
        super.setUp();
        uninitializedInbox = _deployUninitializedInbox();
    }

    function test_propose_RevertWhen_NotActivated() public {
        _setBlobHashes(1);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ActivationRequired.selector);
        vm.prank(proposer);
        uninitializedInbox.propose(bytes(""), encodedInput);
    }

    function test_prove_RevertWhen_NotInitialized() public {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
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
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        uninitializedInbox.prove(encodedInput, bytes("proof"));
    }

    function test_init_RevertWhen_InvalidGenesisBlockHash() public {
        address impl = address(new Inbox(config));

        vm.expectRevert(Inbox.InvalidGenesisBlockHash.selector);
        new ERC1967Proxy(impl, abi.encodeCall(Inbox.init, (address(this), bytes32(0))));
    }

    function test_init_activatesInbox() public {
        Inbox initializedInbox = _deployInbox();
        IInbox.CoreState memory state = initializedInbox.getCoreState();

        assertEq(initializedInbox.activationTimestamp(), uint48(block.timestamp), "activated");
        assertEq(state.nextProposalId, 1, "next proposal id");
    }

    function test_getConfig_returnsImmutableConfig() public view {
        IInbox.Config memory cfg = inbox.getConfig();

        // Verify key config values match what was set during construction
        assertEq(cfg.provingWindow, config.provingWindow, "provingWindow mismatch");
        assertEq(
            cfg.permissionlessProvingDelay,
            config.permissionlessProvingDelay,
            "permissionlessProvingDelay mismatch"
        );
        assertEq(cfg.ringBufferSize, config.ringBufferSize, "ringBufferSize mismatch");
        assertEq(cfg.basefeeSharingPctg, config.basefeeSharingPctg, "basefeeSharingPctg mismatch");
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

/// @notice Tests for Inbox config validation
contract InboxConfigValidationTest is InboxTestBase {
    function test_validateConfig_RevertWhen_ProofVerifierZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.proofVerifier = address(0);

        vm.expectRevert(Inbox.ProofVerifierZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProposerCheckerZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.proposerChecker = address(0);

        vm.expectRevert(Inbox.ProposerCheckerZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_SignalServiceZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.signalService = address(0);

        vm.expectRevert(Inbox.SignalServiceZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_BondTokenZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.bondToken = address(0);

        vm.expectRevert(Inbox.BondTokenZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ProvingWindowZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.provingWindow = 0;

        vm.expectRevert(Inbox.ProvingWindowZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_PermissionlessProvingDelayTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.permissionlessProvingDelay = cfg.provingWindow;

        vm.expectRevert(Inbox.PermissionlessProvingDelayTooSmall.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_RingBufferSizeTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.ringBufferSize = 1; // Must be > 1

        vm.expectRevert(Inbox.RingBufferSizeTooSmall.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_BasefeeSharingPctgTooLarge() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.basefeeSharingPctg = 101; // Must be <= 100

        vm.expectRevert(Inbox.BasefeeSharingPctgTooLarge.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ForcedInclusionFeeInGweiZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.forcedInclusionFeeInGwei = 0;

        vm.expectRevert(Inbox.ForcedInclusionFeeInGweiZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_ForcedInclusionFeeDoubleThresholdZero() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.forcedInclusionFeeDoubleThreshold = 0;

        vm.expectRevert(Inbox.ForcedInclusionFeeDoubleThresholdZero.selector);
        new Inbox(cfg);
    }

    function test_validateConfig_RevertWhen_PermissionlessInclusionMultiplierTooSmall() public {
        IInbox.Config memory cfg = _buildConfig();
        cfg.permissionlessInclusionMultiplier = 1; // Must be > 1

        vm.expectRevert(Inbox.PermissionlessInclusionMultiplierTooSmall.selector);
        new Inbox(cfg);
    }
}
