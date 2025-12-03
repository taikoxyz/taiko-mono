// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxActivationTest
/// @notice Tests for Inbox activation functionality
/// @custom:security-contact security@taiko.xyz
contract InboxActivationTest is InboxTestHelper {
    Inbox public freshInbox;

    function setUp() public override {
        // Don't call super.setUp() - we need unactivated inbox
        super.setUpOnEthereum();

        _deployDependencies();

        // Deploy fresh inbox without activation
        freshInbox = _deployInbox(_createDefaultConfig());

        // Advance to safe state
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_TIMESTAMP);
    }

    // ---------------------------------------------------------------
    // Activation Happy Path Tests
    // ---------------------------------------------------------------

    function test_activate_success() public {
        bytes32 lastPacayaBlockHash = keccak256("last_pacaya_block");

        vm.expectEmit(true, true, true, true);
        emit Inbox.InboxActivated(lastPacayaBlockHash);

        vm.prank(owner);
        freshInbox.activate(lastPacayaBlockHash);

        // Verify activation timestamp is set
        assertGt(freshInbox.activationTimestamp(), 0, "Activation timestamp should be set");

        // Verify genesis proposal hash is stored
        bytes32 genesisHash = freshInbox.getProposalHash(0);
        assertTrue(genesisHash != bytes32(0), "Genesis proposal hash should be stored");
    }

    function test_activate_canBeCalledMultipleTimes_withinWindow() public {
        bytes32 hash1 = keccak256("hash1");
        bytes32 hash2 = keccak256("hash2");

        vm.prank(owner);
        freshInbox.activate(hash1);
        uint40 firstTimestamp = freshInbox.activationTimestamp();

        // Re-activate within the window
        vm.warp(block.timestamp + 1 hours);
        vm.prank(owner);
        freshInbox.activate(hash2);

        // Activation timestamp should remain the same
        assertEq(
            freshInbox.activationTimestamp(),
            firstTimestamp,
            "Activation timestamp should not change on re-activation"
        );
    }

    // ---------------------------------------------------------------
    // Activation Error Path Tests
    // ---------------------------------------------------------------

    function test_activate_RevertWhen_NotOwner() public {
        bytes32 lastPacayaBlockHash = keccak256("last_pacaya_block");

        vm.expectRevert();
        vm.prank(Bob);
        freshInbox.activate(lastPacayaBlockHash);
    }

    function test_activate_RevertWhen_ZeroHash() public {
        vm.expectRevert(Inbox.InvalidLastPacayaBlockHash.selector);
        vm.prank(owner);
        freshInbox.activate(bytes32(0));
    }

    function test_activate_RevertWhen_AfterActivationWindow() public {
        bytes32 hash1 = keccak256("hash1");
        bytes32 hash2 = keccak256("hash2");

        vm.prank(owner);
        freshInbox.activate(hash1);

        // Try to re-activate after the 2-hour window
        vm.warp(block.timestamp + 2 hours + 1);

        vm.expectRevert(Inbox.ActivationPeriodExpired.selector);
        vm.prank(owner);
        freshInbox.activate(hash2);
    }

    // ---------------------------------------------------------------
    // Propose Without Activation Tests
    // ---------------------------------------------------------------

    function test_propose_RevertWhen_NotActivated() public {
        proposerChecker.allowProposer(currentProposer);
        _setupBlobHashes();
        vm.roll(2);

        // Try to propose without activation - should revert because genesis doesn't exist
        IInbox.CoreState memory coreState;
        coreState.proposalHeadContainerBlock = 1;

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        // Genesis proposal with arbitrary values (won't match storage)

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });

        bytes memory proposeData = freshInbox.encodeProposeInput(input);

        vm.expectRevert(Inbox.ProposalHashMismatch.selector);
        vm.prank(currentProposer);
        freshInbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Constructor Error Tests
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_RingBufferSizeZero() public {
        IInbox.Config memory config = _createDefaultConfig();
        config.ringBufferSize = 0;

        // Test at Inbox level since DevnetInbox has hardcoded config
        vm.expectRevert(Inbox.RingBufferSizeZero.selector);
        new TestInboxWithConfig(config);
    }
}

/// @dev Test contract to allow testing Inbox constructor with custom config
contract TestInboxWithConfig is Inbox {
    constructor(IInbox.Config memory _config) Inbox(_config) { }

    function _storeReentryLock(uint8) internal override { }

    function _loadReentryLock() internal pure override returns (uint8) {
        return 1;
    }
}
