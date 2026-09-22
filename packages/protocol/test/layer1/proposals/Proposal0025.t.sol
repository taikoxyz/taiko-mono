// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0025Harness } from "./Proposal0025Harness.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0025 } from "script/layer1/proposals/Proposal0025.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0025Test is Test {
    address internal constant BRIDGE_NEW_IMPL_L1 = 0x1010101010101010101010101010101010101010;
    address internal constant ERC20_VAULT_NEW_IMPL_L1 = 0x1111111111111111111111111111111111111111;
    address internal constant BRIDGE_NEW_IMPL_L2 = 0x2020202020202020202020202020202020202020;
    address internal constant ERC20_VAULT_NEW_IMPL_L2 = 0x4040404040404040404040404040404040404040;

    // TODO(@davidtaikocha): once the four implementations are deployed and written into
    // `Proposal0025.s.sol`, write them out here as literals as well, rather than reading them back
    // from `Proposal0025`, so an edit to a constant there cannot be mirrored here. The
    // `UsesDeployedImplementations` tests below switch from pinning the placeholder guard to
    // pinning these literals as soon as the constants are non-zero.
    address internal constant DEPLOYED_BRIDGE_IMPL_L1 = address(0);
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L1 = address(0);
    address internal constant DEPLOYED_BRIDGE_IMPL_L2 = address(0);
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L2 = address(0);

    Proposal0025Harness internal proposal;

    function setUp() external {
        proposal = new Proposal0025Harness();
    }

    function test_buildL1Actions_EncodesTheBridgeThenTheVaultUpgrade() external view {
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions(_l1());

        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L1.BRIDGE, BRIDGE_NEW_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L1);
    }

    function test_buildL1Actions_RevertsWhileAnImplementationIsMissing() external {
        Proposal0025.L1Deployment memory d = _l1();
        d.bridgeImpl = address(0);
        vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions(d);

        d = _l1();
        d.erc20VaultImpl = address(0);
        vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions(d);
    }

    function test_buildL2Actions_UpgradesTheVaultThenTheBridge() external view {
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions(_l2());

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L2.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L2);
        _assertUpgrades(actions[1], L2.BRIDGE, BRIDGE_NEW_IMPL_L2);
    }

    function test_buildL2Actions_RevertsWhileAnImplementationIsMissing() external {
        Proposal0025.L2Deployment memory d = _l2();
        d.bridgeImpl = address(0);
        vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);

        d = _l2();
        d.erc20VaultImpl = address(0);
        vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions(d);
    }

    /// @dev The DAO executes the L1 actions plus one `sendMessage` that `BuildProposal` appends,
    /// and the fork rehearsal executes exactly this batch. Pins its shape and the message it
    /// carries, decoded from the `sendMessage` calldata rather than rebuilt here.
    function test_buildAllActions_AppendsTheL2MessageAfterTheL1Upgrades() external view {
        Controller.Action[] memory actions = proposal.exposedBuildAllActions(_l1(), _l2());

        assertEq(actions.length, 3);
        _assertUpgrades(actions[0], L1.BRIDGE, BRIDGE_NEW_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, ERC20_VAULT_NEW_IMPL_L1);
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

        (,, Controller.Action[] memory l2Actions) = proposal.exposedBuildL2Actions(_l2());
        assertEq(
            message.data,
            abi.encodeCall(
                IMessageInvocable.onMessageInvocation,
                (abi.encodePacked(uint64(0), abi.encode(l2Actions)))
            )
        );

        // The L2 bridge charges 16 gas per byte of this, rounded up to 32 bytes, plus the message
        // overhead; the relayer budget pinned in `Proposal0025.md` is derived from this size.
        // Re-derive both together when the action list changes.
        assertEq(
            message.data.length, 612, "L2 message size moved; re-derive the pinned relayer budget"
        );
    }

    /// @dev Pins what the no-argument builders forward. While the constants in `Proposal0025.s.sol`
    /// are placeholders they must refuse to encode; once deployed, the forwarded addresses are
    /// the `DEPLOYED_*` literals above rather than reads of `Proposal0025`, so an edit to one of
    /// those constants cannot be mirrored here.
    function test_buildL1Actions_UsesDeployedImplementations() external {
        if (_placeholdersPending()) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL1Actions();
            return;
        }

        assertTrue(DEPLOYED_BRIDGE_IMPL_L1 != address(0), "fill in the DEPLOYED_* literals");
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions();
        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L1.BRIDGE, DEPLOYED_BRIDGE_IMPL_L1);
        _assertUpgrades(actions[1], L1.ERC20_VAULT, DEPLOYED_ERC20_VAULT_IMPL_L1);
    }

    function test_buildL2Actions_UsesDeployedImplementations() external {
        if (_placeholdersPending()) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL2Actions();
            return;
        }

        assertTrue(DEPLOYED_BRIDGE_IMPL_L2 != address(0), "fill in the DEPLOYED_* literals");
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions();
        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 2);
        _assertUpgrades(actions[0], L2.ERC20_VAULT, DEPLOYED_ERC20_VAULT_IMPL_L2);
        _assertUpgrades(actions[1], L2.BRIDGE, DEPLOYED_BRIDGE_IMPL_L2);
    }

    /// @dev `Proposal0025.action.md` is the payload the DAO actually executes, and it is generated
    /// out-of-band by `P=0025 pnpm proposal`. Nothing else in the repository checks that it was
    /// regenerated after the proposal changed, so a stale file would present one set of actions
    /// for review while the code describes another. This compares the committed calldata against
    /// what the proposal builds right now, including the bridge message that wraps the L2 batch.
    /// Skipped, not failed, while the constants are placeholders: the file cannot exist before the
    /// implementations do, and the placeholder guard above is what pins that phase.
    function test_actionFileMatchesTheBuiltCalldata() external {
        if (_placeholdersPending()) {
            vm.skip(true, "Proposal0025 implementations are not deployed yet");
            return;
        }

        string memory file = vm.readFile("script/layer1/proposals/Proposal0025.action.md");

        // Split on the label rather than on backtick position: the file is prettier-formatted by
        // the pre-commit hook, so line breaks are not stable but the label is.
        string[] memory afterLabel = vm.split(file, "- Calldata: `");
        assertEq(afterLabel.length, 2, "action file has no single Calldata line");
        string memory committedHex = vm.split(afterLabel[1], "`")[0];

        assertEq(
            vm.parseBytes(committedHex),
            abi.encode(proposal.exposedBuildAllActions()),
            "Proposal0025.action.md is stale -- regenerate with `P=0025 pnpm proposal`"
        );

        // The generated header names the contract the calldata must be submitted to.
        assertTrue(
            vm.contains(file, vm.toString(L1.DAO_CONTROLLER)),
            "action file targets the wrong contract"
        );
    }

    function _placeholdersPending() internal view returns (bool) {
        return proposal.BRIDGE_NEW_IMPL_L1() == address(0)
            || proposal.ERC20_VAULT_NEW_IMPL_L1() == address(0)
            || proposal.BRIDGE_NEW_IMPL_L2() == address(0)
            || proposal.ERC20_VAULT_NEW_IMPL_L2() == address(0);
    }

    function _l1() internal pure returns (Proposal0025.L1Deployment memory) {
        return Proposal0025.L1Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L1, erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1
        });
    }

    function _l2() internal pure returns (Proposal0025.L2Deployment memory) {
        return Proposal0025.L2Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L2, erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2
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
}
