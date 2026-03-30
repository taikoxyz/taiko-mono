// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { RealTimeInboxTestBase } from "./RealTimeInboxTestBase.sol";
import { IRealTimeInbox } from "src/layer1/core/iface/IRealTimeInbox.sol";
import { RealTimeInbox } from "src/layer1/core/impl/RealTimeInbox.sol";

/// @notice Tests for RealTimeInbox activation, config, and constructor validation.
contract RealTimeInboxActivationTest is RealTimeInboxTestBase {
    // ---------------------------------------------------------------
    // activate()
    // ---------------------------------------------------------------

    function test_activate_succeeds() public {
        RealTimeInbox freshInbox = _deployNonActivatedInbox();

        bytes32 genesisHash = keccak256("genesis");
        vm.expectEmit();
        emit IRealTimeInbox.Activated(genesisHash);
        freshInbox.activate(genesisHash);

        assertEq(freshInbox.lastFinalizedBlockHash(), genesisHash, "lastFinalizedBlockHash");
    }

    function test_activate_RevertWhen_ZeroHash() public {
        RealTimeInbox freshInbox = _deployNonActivatedInbox();

        vm.expectRevert(RealTimeInbox.InvalidGenesisBlockHash.selector);
        freshInbox.activate(bytes32(0));
    }

    function test_activate_RevertWhen_AlreadyActivated() public {
        // The inbox deployed in setUp() is already activated.
        vm.expectRevert(RealTimeInbox.AlreadyActivated.selector);
        inbox.activate(keccak256("another"));
    }

    // ---------------------------------------------------------------
    // getConfig()
    // ---------------------------------------------------------------

    function test_getConfig_returnsCorrectValues() public view {
        IRealTimeInbox.Config memory cfg = inbox.getConfig();

        assertEq(cfg.proofVerifier, address(verifier), "proofVerifier mismatch");
        assertEq(cfg.signalService, address(signalService), "signalService mismatch");
        assertEq(cfg.basefeeSharingPctg, config.basefeeSharingPctg, "basefeeSharingPctg mismatch");
    }

    // ---------------------------------------------------------------
    // constructor validation
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_ProofVerifierZero() public {
        IRealTimeInbox.Config memory cfg = IRealTimeInbox.Config({
            proofVerifier: address(0),
            signalService: address(signalService),
            basefeeSharingPctg: 0
        });

        vm.expectRevert("config: proofVerifier");
        new RealTimeInbox(cfg);
    }

    function test_constructor_RevertWhen_SignalServiceZero() public {
        IRealTimeInbox.Config memory cfg = IRealTimeInbox.Config({
            proofVerifier: address(verifier),
            signalService: address(0),
            basefeeSharingPctg: 0
        });

        vm.expectRevert("config: signalService");
        new RealTimeInbox(cfg);
    }

    function test_constructor_RevertWhen_BasefeeSharingPctgTooLarge() public {
        IRealTimeInbox.Config memory cfg = IRealTimeInbox.Config({
            proofVerifier: address(verifier),
            signalService: address(signalService),
            basefeeSharingPctg: 101
        });

        vm.expectRevert("config: basefeeSharingPctg");
        new RealTimeInbox(cfg);
    }
}
