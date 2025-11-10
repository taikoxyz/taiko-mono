// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { PreconfWhitelistSetup } from "../common/PreconfWhitelistSetup.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { CodecSimple } from "src/layer1/core/impl/CodecSimple.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

abstract contract AbstractInitTest is InboxTestHelper {
    ICodec internal codec;
    address internal initializer;

    function setUp() public virtual override {
        CommonTest.setUp();

        proposerHelper = new PreconfWhitelistSetup();
        _setupDependencies();
        _setupMocks();

        codec = _createCodec();
        initializer = Bob;
    }

    function _createCodec() internal virtual returns (ICodec) {
        return new CodecSimple();
    }

    function test_init_succeeds() public {
        Inbox inbox = _deployInboxProxy();

        vm.prank(owner);
        inbox.init(owner);

        assertEq(inbox.owner(), owner, "owner mismatch");
    }

    function test_init_setsOwnerToCallerWhenOwnerZero() public {
        Inbox inbox = _deployInboxProxy();
        address caller = Carol;

        vm.prank(caller);
        inbox.init(address(0));

        assertEq(inbox.owner(), caller, "owner should default to caller");
    }

    function test_init_RevertWhen_CalledTwice() public {
        Inbox inbox = _deployInboxProxy();

        vm.prank(owner);
        inbox.init(owner);

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        inbox.init(owner);
    }

    function test_activate_succeeds() public {
        Inbox inbox = _deployInboxProxy();

        vm.prank(owner);
        inbox.init(owner);

        vm.recordLogs();
        vm.prank(owner);
        inbox.activate(GENESIS_BLOCK_HASH);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        IInbox.ProposedEventPayload memory payload = _decodeProposedEvent(logs);

        assertEq(payload.proposal.id, 0, "genesis proposal id");
        assertEq(payload.coreState.nextProposalId, 1, "next proposal id");
        assertEq(payload.coreState.lastProposalBlockId, 1, "last proposal block id");
        assertEq(
            payload.coreState.lastFinalizedTransitionHash,
            _expectedTransitionHash(GENESIS_BLOCK_HASH),
            "transition hash"
        );

        bytes32 storedHash = inbox.getProposalHash(0);
        assertEq(storedHash, _expectedProposalHash(payload.proposal), "stored genesis hash");
    }

    function test_activate_RevertWhen_UnauthorizedCaller() public {
        Inbox inbox = _deployInboxProxy();

        vm.prank(owner);
        inbox.init(owner);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(David);
        inbox.activate(GENESIS_BLOCK_HASH);
    }

    function test_activate_SucceedsWhenCalledTwice() public {
        Inbox inbox = _deployInboxProxy();

        vm.prank(owner);
        inbox.init(owner);

        vm.prank(owner);
        inbox.activate(GENESIS_BLOCK_HASH);

        // Should succeed when called again by same owner (for L1 reorgs)
        vm.prank(owner);
        inbox.activate(GENESIS_BLOCK_HASH);

        // Verify state is still correct
        bytes32 storedHash = inbox.getProposalHash(0);
        assertTrue(storedHash != bytes32(0), "genesis proposal should exist");
    }

    function test_activate_RevertWhen_NotInitialized() public {
        Inbox inbox = _deployInboxProxy();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(owner);
        inbox.activate(GENESIS_BLOCK_HASH);
    }

    function _deployInboxProxy() internal returns (Inbox inbox) {
        Inbox implementation = _deployImplementation();
        inbox = Inbox(address(new ERC1967Proxy(address(implementation), "")));
    }

    function _deployImplementation() internal virtual returns (Inbox);

    function _decodeProposedEvent(Vm.Log[] memory logs)
        internal
        view
        returns (IInbox.ProposedEventPayload memory payload)
    {
        bytes32 topic = keccak256("Proposed(bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                bytes memory data = abi.decode(logs[i].data, (bytes));
                return _decodeEvent(data);
            }
        }
        revert("Proposed event not found");
    }

    function _decodeEvent(bytes memory data)
        internal
        view
        virtual
        returns (IInbox.ProposedEventPayload memory)
    {
        return codec.decodeProposedEvent(data);
    }

    function _expectedTransitionHash(bytes32 genesisHash) internal view virtual returns (bytes32) {
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = genesisHash;
        return codec.hashTransition(transition);
    }

    function _expectedProposalHash(IInbox.Proposal memory proposal)
        internal
        view
        virtual
        returns (bytes32)
    {
        return codec.hashProposal(proposal);
    }
}
