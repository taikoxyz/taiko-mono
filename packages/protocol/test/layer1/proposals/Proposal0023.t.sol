// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0023Harness } from "./Proposal0023Harness.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0023 } from "script/layer1/proposals/Proposal0023.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0023Test is Test {
    address internal constant BRIDGE_NEW_IMPL_L1 = 0x1010101010101010101010101010101010101010;
    address internal constant ERC20_VAULT_NEW_IMPL_L1 = 0x1111111111111111111111111111111111111111;
    address internal constant BRIDGE_NEW_IMPL_L2 = 0x2020202020202020202020202020202020202020;
    address internal constant L2_SHARED_RESOLVER = 0x3030303030303030303030303030303030303030;
    address internal constant ERC20_VAULT_NEW_IMPL_L2 = 0x4040404040404040404040404040404040404040;
    address internal constant BRIDGED_ERC20_NEW_IMPL_L2 =
        0x5050505050505050505050505050505050505050;

    // The deployed addresses, written out as literals rather than read back from `Proposal0023`,
    // so an edit to a constant there cannot be mirrored here.
    address internal constant DEPLOYED_BRIDGE_IMPL_L1 = 0xA15dca0A72da684f20e0FC708DECFb230a715462;
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L1 =
        0x32E47c04E8c329E8c10062731448e7658aDEEB8e;
    address internal constant DEPLOYED_BRIDGE_IMPL_L2 = 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb;
    address internal constant DEPLOYED_L2_SHARED_RESOLVER =
        0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984;
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L2 =
        0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3;
    address internal constant DEPLOYED_BRIDGED_ERC20_IMPL_L2 =
        0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944;

    Proposal0023Harness internal proposal;

    function setUp() external {
        proposal = new Proposal0023Harness();
    }

    function test_buildL1Actions_EncodesBridgeThenVaultUpgrade() external view {
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions(_l1());

        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L1.BRIDGE, BRIDGE_NEW_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L1);
    }

    function test_buildL1Actions_RevertsWhileAnImplementationIsMissing() external {
        Proposal0023.L1Deployment memory d = _l1();
        d.bridgeImpl = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions(d);

        d = _l1();
        d.erc20VaultImpl = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions(d);
    }

    function test_buildL2Actions_RegistersEveryNameBeforeUpgrading() external view {
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions(_l2());

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 7);

        _assertRegisters(actions[0], 1, LibNames.B_BRIDGE, L1.BRIDGE);
        _assertRegisters(actions[1], 167_000, LibNames.B_BRIDGE, L2.BRIDGE);
        _assertRegisters(actions[2], 1, LibNames.B_ERC20_VAULT, L1.ERC20_VAULT);
        _assertRegisters(actions[3], 167_000, LibNames.B_ERC20_VAULT, L2.ERC20_VAULT);
        _assertRegisters(actions[4], 167_000, LibNames.B_BRIDGED_ERC20, BRIDGED_ERC20_NEW_IMPL_L2);
        _assertUpgrades(actions[5], L2.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L2);
        _assertUpgrades(actions[6], L2.BRIDGE, BRIDGE_NEW_IMPL_L2);
    }

    function test_buildL2Actions_RevertsWhileAnAddressIsMissing() external {
        Proposal0023.L2Deployment memory d = _l2();
        d.sharedResolver = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);

        d = _l2();
        d.bridgeImpl = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);

        d = _l2();
        d.erc20VaultImpl = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);

        d = _l2();
        d.bridgedErc20Impl = address(0);
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);
    }

    /// @dev The DAO executes the L1 actions plus one `sendMessage` that `BuildProposal` appends,
    /// and the fork rehearsal executes exactly this batch. Pins its shape and the message it
    /// carries, decoded from the `sendMessage` calldata rather than rebuilt here.
    function test_buildAllActions_AppendsTheL2MessageAfterTheL1Upgrades() external view {
        Controller.Action[] memory actions = proposal.exposedBuildAllActions();

        assertEq(actions.length, 3);
        _assertUpgrades(actions[0], L1.BRIDGE, DEPLOYED_BRIDGE_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, DEPLOYED_ERC20_VAULT_IMPL_L1);
        assertEq(actions[2].target, L1.BRIDGE);
        assertEq(actions[2].value, 0);

        IBridge.Message memory message = proposal.decodeSendMessage(actions[2].data);
        assertEq(message.srcOwner, L1.DAO_CONTROLLER);
        assertEq(message.destOwner, L2.PERMISSIONLESS_EXECUTOR);
        assertEq(message.destChainId, 167_000);
        assertEq(message.to, L2.DELEGATE_CONTROLLER);
        assertEq(message.gasLimit, 5_000_000);
        assertEq(message.value, 0);
        assertEq(message.fee, 0);

        (,, Controller.Action[] memory l2Actions) = proposal.exposedBuildL2Actions();
        assertEq(
            message.data,
            abi.encodeCall(
                IMessageInvocable.onMessageInvocation,
                (abi.encodePacked(uint64(0), abi.encode(l2Actions)))
            )
        );

        // The 1.10.0 L2 bridge charges 16 gas per byte of this, rounded up to 32 bytes, plus 416
        // bytes of message overhead; the relayer budget pinned in `Proposal0023Fork.t.sol` is
        // derived from this size. Re-derive both together when the action list changes.
        assertEq(
            message.data.length, 2052, "L2 message size moved; re-derive the pinned relayer budget"
        );
    }

    /// @dev Pins what the no-argument builders forward. The encoding tests above call the
    /// parameterised overloads directly and so bypass the forwarding lines entirely. The expected
    /// addresses are written as literals rather than read back from `Proposal0023`, so an edit to
    /// a constant there cannot be mirrored here. Mirrors
    /// `test_buildL1Actions_UsesDeployedImplementations` in `Proposal0017.t.sol`.
    function test_buildL1Actions_UsesDeployedImplementations() external view {
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions();

        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L1.BRIDGE, DEPLOYED_BRIDGE_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, DEPLOYED_ERC20_VAULT_IMPL_L1);
    }

    function test_buildL2Actions_UsesDeployedImplementations() external view {
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions();

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 7);

        for (uint256 i; i < 5; ++i) {
            assertEq(actions[i].target, DEPLOYED_L2_SHARED_RESOLVER);
        }
        assertEq(
            actions[4].data,
            abi.encodeCall(
                DefaultResolver.registerAddress,
                (uint256(167_000), LibNames.B_BRIDGED_ERC20, DEPLOYED_BRIDGED_ERC20_IMPL_L2)
            )
        );
        _assertUpgrades(actions[5], L2.ERC20_VAULT, DEPLOYED_ERC20_VAULT_IMPL_L2);
        _assertUpgrades(actions[6], L2.BRIDGE, DEPLOYED_BRIDGE_IMPL_L2);
    }

    /// @dev `Proposal0023.action.md` is the payload the DAO actually executes, and it is generated
    /// out-of-band by `P=0023 pnpm proposal`. Nothing else in the repository checks that it was
    /// regenerated after the proposal changed, so a stale file would present one set of actions
    /// for review while the code describes another. This compares the committed calldata against
    /// what the proposal builds right now — including the bridge message that wraps the L2 batch,
    /// which `BuildProposal` builds privately and `Proposal0023Harness` reproduces. Every address is
    /// final, so a missing file is a failure, not a placeholder phase to skip.
    function test_actionFileMatchesTheBuiltCalldata() external {
        string memory file = vm.readFile("script/layer1/proposals/Proposal0023.action.md");

        // Split on the label rather than on backtick position: the file is prettier-formatted by
        // the pre-commit hook, so line breaks are not stable but the label is.
        string[] memory afterLabel = vm.split(file, "- Calldata: `");
        assertEq(afterLabel.length, 2, "action file has no single Calldata line");
        string memory committedHex = vm.split(afterLabel[1], "`")[0];

        assertEq(
            vm.parseBytes(committedHex),
            abi.encode(proposal.exposedBuildAllActions()),
            "Proposal0023.action.md is stale -- regenerate with `P=0023 pnpm proposal`"
        );

        // The generated header names the contract the calldata must be submitted to.
        assertTrue(
            vm.contains(file, vm.toString(L1.DAO_CONTROLLER)),
            "action file targets the wrong contract"
        );
    }

    function _l1() internal pure returns (Proposal0023.L1Deployment memory) {
        return Proposal0023.L1Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L1, erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1
        });
    }

    function _l2() internal pure returns (Proposal0023.L2Deployment memory) {
        return Proposal0023.L2Deployment({
            sharedResolver: L2_SHARED_RESOLVER,
            bridgeImpl: BRIDGE_NEW_IMPL_L2,
            erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2,
            bridgedErc20Impl: BRIDGED_ERC20_NEW_IMPL_L2
        });
    }

    function _assertUpgrades(
        Controller.Action memory _action,
        address _proxy,
        address _newImpl
    )
        internal
        pure
    {
        assertEq(_action.target, _proxy);
        assertEq(_action.value, 0);
        assertEq(_action.data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl)));
    }

    function _assertRegisters(
        Controller.Action memory _action,
        uint256 _chainId,
        bytes32 _name,
        address _addr
    )
        internal
        pure
    {
        assertEq(_action.target, L2_SHARED_RESOLVER);
        assertEq(_action.value, 0);
        assertEq(
            _action.data, abi.encodeCall(DefaultResolver.registerAddress, (_chainId, _name, _addr))
        );
    }
}
