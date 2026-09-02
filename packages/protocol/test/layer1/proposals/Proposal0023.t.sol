// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

    // The bridge-side addresses deployed on 2026-08-31, written out as literals so an accidental
    // edit to `Proposal0023` while the vault placeholders are being filled in cannot go unnoticed.
    address internal constant DEPLOYED_BRIDGE_IMPL_L1 = 0xA15dca0A72da684f20e0FC708DECFb230a715462;
    address internal constant DEPLOYED_BRIDGE_IMPL_L2 = 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb;
    address internal constant DEPLOYED_L2_SHARED_RESOLVER =
        0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984;

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
    /// carries.
    function test_buildAllActions_AppendsTheL2MessageAfterTheL1Upgrades() external view {
        Controller.Action[] memory actions = proposal.exposedBuildAllActions(_l1(), _l2());

        assertEq(actions.length, 3);
        _assertUpgrades(actions[0], L1.BRIDGE, BRIDGE_NEW_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L1);

        IBridge.Message memory message = proposal.exposedBuildL2Message(_l2());
        assertEq(actions[2].target, L1.BRIDGE);
        assertEq(actions[2].value, 0);
        assertEq(actions[2].data, abi.encodeCall(IBridge.sendMessage, (message)));

        assertEq(message.srcOwner, L1.DAO_CONTROLLER);
        assertEq(message.destOwner, L2.PERMISSIONLESS_EXECUTOR);
        assertEq(message.destChainId, 167_000);
        assertEq(message.to, L2.DELEGATE_CONTROLLER);
        assertEq(message.gasLimit, 5_000_000);
        assertEq(message.value, 0);
        assertEq(message.fee, 0);

        (,, Controller.Action[] memory l2Actions) = proposal.exposedBuildL2Actions(_l2());
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

    /// @dev While the vault implementations are placeholders, the no-argument builders must refuse
    /// to encode an upgrade to address(0). That refusal is also what keeps `P=0023 pnpm proposal`
    /// from generating executable calldata too early. Replace this test when the vault addresses
    /// land: assert that the no-argument builders return what the parameterised builders return
    /// for the deployed addresses, written as literals (the struct's named fields already rule out
    /// a transposed forward).
    function test_placeholderConstantsStillGuardTheBuilders() external {
        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions();

        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions();

        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildAllActions();

        // The bridge-side constants are deployed and must not move while the vault constants are
        // filled in.
        assertEq(proposal.BRIDGE_NEW_IMPL_L1(), DEPLOYED_BRIDGE_IMPL_L1);
        assertEq(proposal.BRIDGE_NEW_IMPL_L2(), DEPLOYED_BRIDGE_IMPL_L2);
        assertEq(proposal.L2_SHARED_RESOLVER(), DEPLOYED_L2_SHARED_RESOLVER);
    }

    /// @dev `Proposal0023.action.md` is the payload the DAO actually executes, and it is generated
    /// out-of-band by `P=0023 pnpm proposal`. Nothing else in the repository checks that it was
    /// regenerated after the proposal changed, so a stale file would present one set of actions
    /// for review while the code describes another. This compares the committed calldata against
    /// what `_buildAllActions` builds right now — including the bridge message that wraps the L2
    /// batch. The file cannot exist while any constant is a placeholder, so the test skips until
    /// the vault implementations are deployed and the file is regenerated.
    function test_actionFileMatchesTheBuiltCalldata() external {
        string memory path = "script/layer1/proposals/Proposal0023.action.md";
        if (!vm.exists(path)) {
            vm.skip(
                true,
                "Proposal0023.action.md is not generated yet: deploy the vault implementations, "
                "fill in the constants and run `P=0023 pnpm proposal`"
            );
            return;
        }

        string memory file = vm.readFile(path);

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

contract Proposal0023Harness is Proposal0023 {
    function exposedBuildAllActions() external pure returns (Controller.Action[] memory) {
        return _buildAllActions();
    }

    function exposedBuildAllActions(
        L1Deployment memory _l1,
        L2Deployment memory _l2
    )
        external
        pure
        returns (Controller.Action[] memory)
    {
        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions(_l2);
        return _buildAllActions(buildL1Actions(_l1), l2ExecutionId, l2GasLimit, l2Actions);
    }

    function exposedBuildL2Message(L2Deployment memory _l2)
        external
        pure
        returns (IBridge.Message memory)
    {
        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions(_l2);
        return _buildL2Message(l2ExecutionId, l2GasLimit, l2Actions);
    }

    function exposedBuildL1Actions() external pure returns (Controller.Action[] memory) {
        return buildL1Actions();
    }

    function exposedBuildL1Actions(L1Deployment memory _l1)
        external
        pure
        returns (Controller.Action[] memory)
    {
        return buildL1Actions(_l1);
    }

    function exposedBuildL2Actions()
        external
        pure
        returns (uint64, uint32, Controller.Action[] memory)
    {
        return buildL2Actions();
    }

    function exposedBuildL2Actions(L2Deployment memory _l2)
        external
        pure
        returns (uint64, uint32, Controller.Action[] memory)
    {
        return buildL2Actions(_l2);
    }
}
