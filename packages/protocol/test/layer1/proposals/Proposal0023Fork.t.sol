// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @notice Rehearses the Proposal0023 upgrades against live mainnet state.
/// @dev Skipped unless `L1_FORK_URL` / `L2_FORK_URL` are set, because CI configures no RPC
/// endpoints. Run with:
///
///   L1_FORK_URL=<l1 rpc> L2_FORK_URL=https://rpc.mainnet.taiko.xyz \
///     FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0023ForkTest -vv
///
/// `Proposal0023.t.sol` proves the proposal encodes the right calldata. It cannot prove the
/// upgrade works, and the L2 leg is where that distinction matters: the live L2 bridge runs the
/// protocol 1.10.0 implementation from October 2024 and must upgrade *itself* from inside its own
/// `processMessage` frame, because the proxy is owned by the DelegateController, which is only
/// reachable through a bridged message the bridge processes.
/// @custom:security-contact security@taiko.xyz
contract Proposal0023ForkTest is Test {
    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The implementations each proxy must still be running when the rehearsal starts. Both
    /// forks are taken at head, so once Proposal0023 executes these tests would otherwise rehearse
    /// current -> current and stay green while no longer covering the transition they exist for —
    /// the L2 one silently stops exercising the 1.10.0 jump. Asserting the starting implementation
    /// fails loudly instead. It is preferred over a pinned fork block because pinning needs an
    /// archive node; the blocks the rehearsal was captured at are named in the failure messages for
    /// anyone who has one.
    address private constant _LIVE_BRIDGE_IMPL_L1 = 0x1c94D798CFA08F396E5BA9F81697289c53273381;
    address private constant _LIVE_BRIDGE_IMPL_L2 = 0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83;

    function test_l1_bridgeUpgradeAgainstLiveState() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        assertEq(
            _implementationOf(L1.BRIDGE),
            _LIVE_BRIDGE_IMPL_L1,
            "L1 fork is not pre-upgrade; pin --fork-block-number 25875170 against an archive node"
        );

        address newImpl = address(
            new Bridge(
                L1.SHARED_RESOLVER, L1.SIGNAL_SERVICE, L1.QUOTA_MANAGER, L1.MULTISIG_ADMIN_TAIKO_ETH
            )
        );

        vm.prank(L1.DAO_CONTROLLER);
        UUPSUpgradeable(L1.BRIDGE).upgradeTo(newImpl);

        Bridge bridge = Bridge(payable(L1.BRIDGE));
        assertEq(_implementationOf(L1.BRIDGE), newImpl);
        assertEq(bridge.resolver(), L1.SHARED_RESOLVER);
        assertEq(address(bridge.signalService()), L1.SIGNAL_SERVICE);
        assertEq(address(bridge.quotaManager()), L1.QUOTA_MANAGER);
        assertEq(bridge.pauser(), L1.MULTISIG_ADMIN_TAIKO_ETH);

        (bool enabled, address destBridge) = bridge.isDestChainEnabled(167_000);
        assertTrue(enabled);
        assertEq(destBridge, L2.BRIDGE);
    }

    function test_l2_selfUpgradeThroughProcessMessage() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(L2.PERMISSIONLESS_EXECUTOR);
    }

    /// @dev The same rehearsal driven by a relayer rather than the destination owner. When the
    /// caller is the destOwner the legacy bridge forwards `gasleft()`, so the executor case never
    /// exercises the proposal's 5,000,000 gas limit at all; any caller may process a message, and
    /// a relayer instead receives `_invocationGasLimit`, which is what this case covers.
    function test_l2_selfUpgradeThroughProcessMessage_byRelayer() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(makeAddr("relayer"));
    }

    /// @dev Runs the L2 rehearsal with `_caller` processing the governance message.
    /// @param _caller The address that calls `processMessage`.
    function _rehearseL2Upgrade(address _caller) private {
        Bridge bridge = Bridge(payable(L2.BRIDGE));

        assertEq(
            _implementationOf(L2.BRIDGE),
            _LIVE_BRIDGE_IMPL_L2,
            "L2 fork is not pre-upgrade; pin --fork-block-number 10785761 against an archive node"
        );
        uint64 messageIdBefore = bridge.nextMessageId();
        address ownerBefore = bridge.owner();

        // Deploy exactly what DeployBridgeUpgradeL2 deploys.
        address resolverProxy = address(
            new ERC1967Proxy(
                address(new DefaultResolver()),
                abi.encodeCall(DefaultResolver.init, (L2.DELEGATE_CONTROLLER))
            )
        );
        address newImpl =
            address(new Bridge(resolverProxy, L2.SIGNAL_SERVICE, address(0), address(0)));

        // Deliver the three L2 actions the way governance will: as a processMessage call on the
        // bridge itself, not by pranking the DelegateController. That is what exercises the
        // mid-call self-upgrade.
        IBridge.Message memory message = _governanceMessage(resolverProxy, newImpl);

        // A valid signal proof cannot be synthesised on a fork, and the signal service is not what
        // this test exercises.
        vm.mockCall(
            L2.SIGNAL_SERVICE,
            abi.encodeWithSelector(ISignalService.proveSignalReceived.selector),
            abi.encode(uint256(0))
        );

        // On the relayer branch the invocation receives message.gasLimit minus the message's own
        // minimum, not gasleft(). Pin that budget so the 5,000,000 in the proposal is shown to be
        // sufficient rather than assumed: 5,000,000 - (22,528 calldata cost + 800,000 GAS_RESERVE)
        // for this message's 964 bytes of data, roughly twenty times what the three actions need.
        if (_caller != message.destOwner) {
            assertEq(
                message.gasLimit - bridge.getMessageMinGasLimit(message.data.length),
                4_177_472,
                "relayer invocation budget moved; re-derive it before trusting this rehearsal"
            );
        }

        vm.prank(_caller);
        (IBridge.Status status, IBridge.StatusReason reason) = bridge.processMessage(message, "");

        // A passing transaction is NOT evidence the upgrade worked. The 1.10.0 _invokeMessageCall
        // uses a raw call, so a reverting invocation becomes RETRIABLE without reverting
        // processMessage. Assert the status as well as the slot; a silent failure fails here.
        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(_implementationOf(L2.BRIDGE), newImpl);

        // The resolver path the legacy registry could not serve now works. This is the call that
        // reverts if the wiring is wrong.
        (bool enabled, address destBridge) = bridge.isDestChainEnabled(1);
        assertTrue(enabled);
        assertEq(destBridge, L1.BRIDGE);

        // Storage survived the 1.10.0 to main jump, and the new immutables read as deployed.
        assertEq(bridge.nextMessageId(), messageIdBefore);
        assertEq(bridge.owner(), ownerBefore);
        assertEq(bridge.resolver(), resolverProxy);
        assertEq(address(bridge.quotaManager()), address(0));
        assertEq(bridge.pauser(), address(0));

        // The upgraded bridge can still send. gasLimit must clear
        // getMessageMinGasLimit(0) = _messageCalldataCost(0) 6,656 + GAS_RESERVE 800,000 =
        // 806,656; below it _invocationGasLimit returns 0 and sendMessage reverts
        // B_INVALID_GAS_LIMIT. Deliberately not 0, which would short-circuit that validation.
        IBridge.Message memory outbound;
        outbound.srcChainId = 167_000;
        outbound.destChainId = 1;
        outbound.srcOwner = address(this);
        outbound.destOwner = address(this);
        outbound.to = address(this);
        outbound.gasLimit = 1_000_000;
        bridge.sendMessage(outbound);

        assertEq(bridge.nextMessageId(), messageIdBefore + 1);
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

    /// @dev Builds the L1 to L2 message BuildProposal wraps the L2 actions into.
    /// @param _resolverProxy The newly deployed L2 resolver proxy.
    /// @param _newImpl The newly deployed L2 bridge implementation.
    /// @return message_ The message to hand to processMessage.
    function _governanceMessage(
        address _resolverProxy,
        address _newImpl
    )
        private
        pure
        returns (IBridge.Message memory message_)
    {
        Controller.Action[] memory actions = new Controller.Action[](3);
        actions[0] = Controller.Action({
            target: _resolverProxy,
            value: 0,
            data: abi.encodeCall(
                DefaultResolver.registerAddress, (uint256(1), LibNames.B_BRIDGE, L1.BRIDGE)
            )
        });
        actions[1] = Controller.Action({
            target: _resolverProxy,
            value: 0,
            data: abi.encodeCall(
                DefaultResolver.registerAddress, (uint256(167_000), LibNames.B_BRIDGE, L2.BRIDGE)
            )
        });
        actions[2] = Controller.Action({
            target: L2.BRIDGE, value: 0, data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });

        message_.id = 999_999;
        message_.from = L1.DAO_CONTROLLER;
        message_.srcChainId = 1;
        message_.destChainId = 167_000;
        message_.srcOwner = L1.DAO_CONTROLLER;
        message_.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message_.to = L2.DELEGATE_CONTROLLER;
        message_.gasLimit = 5_000_000;
        message_.data = abi.encodeCall(
            IMessageInvocable.onMessageInvocation,
            (abi.encodePacked(uint64(0), abi.encode(actions)))
        );
    }
}
