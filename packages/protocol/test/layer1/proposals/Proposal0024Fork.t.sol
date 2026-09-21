// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0024Harness } from "./Proposal0024Harness.sol";
import { Test } from "forge-std/src/Test.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @notice Rehearses the Proposal0024 upgrade against live mainnet state.
/// @dev Skipped unless `L1_FORK_URL` is set, because CI configures no RPC endpoints. Run with:
///
///   L1_FORK_URL=<l1 rpc> FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0024ForkTest -vv
///
/// `Proposal0024.t.sol` proves the proposal encodes the right calldata and that the new
/// implementation's configuration differs from the live one only in the sharing percentage. This
/// rehearsal proves the upgrade itself against the live proxy: the DAO controller can perform it,
/// and afterwards the proxy answers the new percentage while everything it stores — core state,
/// proposal hashes, the forced-inclusion queue, owner, activation timestamp and initializer
/// version — reads exactly as before.
///
/// The rehearsal executes exactly what the DAO will: the calldata `Proposal0024` builds from its
/// constant, against the implementation that constant names, which already exists on mainnet.
/// Nothing is deployed by the test.
/// @custom:security-contact security@taiko.xyz
contract Proposal0024ForkTest is Test {
    /// @dev Live values read before the upgrade, compared against afterwards.
    struct Before {
        IInbox.Config config;
        IInbox.CoreState coreState;
        uint48 activationTimestamp;
        address owner;
        // The proxy's storage slot 0, whose lowest byte is the initializer version.
        bytes32 slot0;
        uint48 forcedInclusionHead;
        uint48 forcedInclusionTail;
        uint64 forcedInclusionFee;
        bytes32 lastProposalHash;
        bytes32 lastFinalizedProposalHash;
    }

    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The implementation the proxy must still be running when the rehearsal starts (Unzen,
    /// Proposal0019). The fork is taken at head, so once Proposal0024 executes these tests would
    /// otherwise rehearse current -> current and stay green while no longer covering the
    /// transition they exist for. Asserting the starting implementation fails loudly instead.
    address private constant _LIVE_INBOX_IMPL = 0x5253D4C91e80b880DdB54B78E74082Abe066F6b9;

    error ActionReverted(uint256 index);

    function test_l1_upgradesAgainstLiveState() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        assertEq(
            _implementationOf(L1.INBOX),
            _LIVE_INBOX_IMPL,
            "L1 fork is not pre-upgrade; pin --fork-block-number 25961507 against an archive node"
        );

        Before memory before = _snapshot();
        assertEq(before.config.basefeeSharingPctg, 75, "live inbox does not share 75 today");
        assertEq(before.owner, L1.DAO_CONTROLLER, "inbox is not owned by the DAO controller");
        assertEq(uint8(uint256(before.slot0)), 3, "inbox initializer version is not 3");

        (address newImpl, Controller.Action[] memory actions) = _implementationAndBatch();
        assertGt(newImpl.code.length, 0, "inbox implementation is not deployed");
        assertEq(actions.length, 1);

        // Execute the batch the way the DAO controller will: the one upgradeTo, from the
        // controller, which owns the proxy.
        _executeAs(L1.DAO_CONTROLLER, actions);

        assertEq(_implementationOf(L1.INBOX), newImpl);
        _assertOnlyTheSharingPercentageChanged(before);
    }

    /// @dev The check `P=0024 pnpm proposal:dryrun:l1` performs: the DAO controller executes the
    /// batch itself and reverts `DryrunSucceeded`. `dryrun` is permissionless, so no prank.
    function test_l1_dryrunSucceeds() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        assertEq(_implementationOf(L1.INBOX), _LIVE_INBOX_IMPL, "L1 fork is not pre-upgrade");

        (, Controller.Action[] memory actions) = _implementationAndBatch();

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        Controller(payable(L1.DAO_CONTROLLER)).dryrun(abi.encode(actions));

        assertEq(_implementationOf(L1.INBOX), _LIVE_INBOX_IMPL, "dryrun left the proxy upgraded");
    }

    /// @dev The implementation the batch upgrades to, as the proposal names it, and the committed
    /// batch: what `Proposal0024.action.md` carries.
    /// @return impl_ The implementation.
    /// @return actions_ The batch.
    function _implementationAndBatch()
        private
        returns (address impl_, Controller.Action[] memory actions_)
    {
        Proposal0024Harness harness = new Proposal0024Harness();
        impl_ = harness.MAINNET_INBOX_NEW_IMPL();
        actions_ = harness.exposedBuildAllActions();
    }

    /// @dev Reads everything the upgrade must leave alone, plus the configuration.
    /// @return before_ The live values.
    function _snapshot() private view returns (Before memory before_) {
        Inbox inbox = Inbox(L1.INBOX);

        before_.config = inbox.getConfig();
        before_.coreState = inbox.getCoreState();
        before_.activationTimestamp = inbox.activationTimestamp();
        before_.owner = inbox.owner();
        before_.slot0 = vm.load(L1.INBOX, bytes32(0));
        (before_.forcedInclusionHead, before_.forcedInclusionTail) =
            IForcedInclusionStore(L1.INBOX).getForcedInclusionState();
        before_.forcedInclusionFee = inbox.getCurrentForcedInclusionFee();
        before_.lastProposalHash = inbox.getProposalHash(before_.coreState.nextProposalId - 1);
        before_.lastFinalizedProposalHash =
            inbox.getProposalHash(before_.coreState.lastFinalizedProposalId);
    }

    /// @dev After the upgrade the proxy answers the new percentage, the same configuration
    /// otherwise, and the same storage.
    /// @param _before The values read before the upgrade.
    function _assertOnlyTheSharingPercentageChanged(Before memory _before) private view {
        Inbox inbox = Inbox(L1.INBOX);

        IInbox.Config memory config = inbox.getConfig();
        assertEq(config.basefeeSharingPctg, 100);
        config.basefeeSharingPctg = _before.config.basefeeSharingPctg;
        assertEq(
            abi.encode(config),
            abi.encode(_before.config),
            "configuration changed beyond the sharing percentage"
        );

        assertEq(abi.encode(inbox.getCoreState()), abi.encode(_before.coreState));
        assertEq(inbox.activationTimestamp(), _before.activationTimestamp);
        assertEq(inbox.owner(), _before.owner);
        assertEq(vm.load(L1.INBOX, bytes32(0)), _before.slot0, "initializer version moved");

        (uint48 head, uint48 tail) = IForcedInclusionStore(L1.INBOX).getForcedInclusionState();
        assertEq(head, _before.forcedInclusionHead);
        assertEq(tail, _before.forcedInclusionTail);
        assertEq(inbox.getCurrentForcedInclusionFee(), _before.forcedInclusionFee);

        assertEq(
            inbox.getProposalHash(_before.coreState.nextProposalId - 1), _before.lastProposalHash
        );
        assertEq(
            inbox.getProposalHash(_before.coreState.lastFinalizedProposalId),
            _before.lastFinalizedProposalHash
        );
    }

    /// @dev Executes `_actions` one by one from `_controller`, the way `Controller._executeActions`
    /// does, aborting on the first failure. The failure is a custom error rather than an assertion
    /// with a concatenated message: this helper has a single caller, so the via-IR build of the
    /// `layer1o` profile inlines it into the test, and the message's temporaries pushed the loop
    /// one slot past the stack limit there.
    /// @param _controller The controller that executes the batch.
    /// @param _actions The actions.
    function _executeAs(address _controller, Controller.Action[] memory _actions) private {
        for (uint256 i; i < _actions.length; ++i) {
            vm.prank(_controller);
            (bool success,) = _actions[i].target.call{ value: _actions[i].value }(_actions[i].data);
            require(success, ActionReverted(i));
        }
    }

    /// @dev Selects a fork from `_envVar`, or marks the test skipped when it is unset.
    /// @param _envVar Name of the environment variable holding the RPC URL.
    /// @return forked_ True when a fork was selected and the test should continue.
    function _forkOrSkip(string memory _envVar) private returns (bool forked_) {
        string memory url = vm.envOr(_envVar, string(""));
        if (bytes(url).length == 0) {
            vm.skip(true, string.concat(_envVar, " is not set"));
            return false;
        }
        vm.createSelectFork(url);
        return true;
    }

    /// @dev Reads a proxy's EIP-1967 implementation slot.
    /// @param _proxy The proxy to read.
    /// @return impl_ The implementation address it delegates to.
    function _implementationOf(address _proxy) private view returns (address impl_) {
        impl_ = address(uint160(uint256(vm.load(_proxy, _IMPL_SLOT))));
    }
}
