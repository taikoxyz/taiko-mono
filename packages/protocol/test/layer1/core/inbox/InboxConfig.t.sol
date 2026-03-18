// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Tests for Inbox configuration
contract InboxConfigTest is InboxTestBase {
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
