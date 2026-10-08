// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0025Harness } from "./Proposal0025Harness.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0025 } from "script/layer1/proposals/Proposal0025.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { IResolver } from "src/shared/common/IResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0025Test is Test {
    address internal constant BRIDGE_NEW_IMPL_L1 = 0x1010101010101010101010101010101010101010;
    address internal constant ERC20_VAULT_NEW_IMPL_L1 = 0x1111111111111111111111111111111111111111;
    address internal constant ERC721_VAULT_NEW_IMPL_L1 = 0x1212121212121212121212121212121212121212;
    address internal constant ERC1155_VAULT_NEW_IMPL_L1 =
        0x1313131313131313131313131313131313131313;
    address internal constant BRIDGED_ERC721_L1 = 0x1414141414141414141414141414141414141414;
    address internal constant BRIDGED_ERC1155_L1 = 0x1515151515151515151515151515151515151515;
    address internal constant BRIDGE_NEW_IMPL_L2 = 0x2020202020202020202020202020202020202020;
    address internal constant ERC20_VAULT_NEW_IMPL_L2 = 0x4040404040404040404040404040404040404040;
    address internal constant ERC721_VAULT_NEW_IMPL_L2 = 0x4242424242424242424242424242424242424242;
    address internal constant ERC1155_VAULT_NEW_IMPL_L2 =
        0x4343434343434343434343434343434343434343;
    address internal constant BRIDGED_ERC721_L2 = 0x4444444444444444444444444444444444444444;
    address internal constant BRIDGED_ERC1155_L2 = 0x4545454545454545454545454545454545454545;

    // The deployed contracts, written out as literals rather than read back from `Proposal0025`,
    // `LibL1Addrs` or `LibL2Addrs`, so an edit to a constant there cannot be mirrored here. The
    // bridged-token literals are what catches a library still naming the legacy implementations.
    address internal constant DEPLOYED_BRIDGE_IMPL_L1 = 0xe6BF63dCc936063caD2300f32DaA67d9eE5c57b6;
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L1 =
        0xd429A698d19b5789ce6Eb72d8B3ae9fad3b28A92;
    address internal constant DEPLOYED_ERC721_VAULT_IMPL_L1 =
        0x611f3Dc278A14b6ED14410Cd9d56E1721cf33802;
    address internal constant DEPLOYED_ERC1155_VAULT_IMPL_L1 =
        0xca775D0Bb8CEFe388E344f75De91Aebd0E73c58E;
    address internal constant DEPLOYED_BRIDGED_ERC721_L1 =
        0xD9c9dB7519011437C54BCD32495c0347A410bc4D;
    address internal constant DEPLOYED_BRIDGED_ERC1155_L1 =
        0x35001aB6f53CF9fE583653Ca3F56cae75E8C385e;
    address internal constant DEPLOYED_BRIDGE_IMPL_L2 = 0xF372Db3F06AcaB3347697866d2047a54D1BA8eB3;
    address internal constant DEPLOYED_ERC20_VAULT_IMPL_L2 =
        0x25D8465fD0C8D89bfdE910E47c41f4E465672B5c;
    address internal constant DEPLOYED_ERC721_VAULT_IMPL_L2 =
        0x4cAb75DBE321084fD15c7AA9f7398e073A7EaBd0;
    address internal constant DEPLOYED_ERC1155_VAULT_IMPL_L2 =
        0xe148CceFFcd5494301c20e047634995C60611e57;
    address internal constant DEPLOYED_BRIDGED_ERC721_L2 =
        0x71c2f41AEDe913AAEf2c62596E03702E348D6Cd0;
    address internal constant DEPLOYED_BRIDGED_ERC1155_L2 =
        0x7dF8bfBf0f09e94200b6a158b421e2CCaCc4830F;

    Proposal0025Harness internal proposal;

    function setUp() external {
        proposal = new Proposal0025Harness();
    }

    function test_buildL1Actions_EncodesTheUpgradesAndTheBridgedNftRegistrations() external view {
        _assertL1Actions(proposal.exposedBuildL1Actions(_l1()), _l1());
    }

    function test_buildL1Actions_RevertsWhileAnAddressIsMissing() external {
        for (uint256 i; i < 6; ++i) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL1Actions(_l1WithZero(i));
        }
    }

    /// @dev The batch opens by resolving the L1 bridge on the L2 resolver, which only
    /// Proposal0024's L2 batch registers: delivered before that one, this batch reverts at its
    /// first action and the message stays retriable.
    function test_buildL2Actions_RequiresProposal0024ThenUpgradesWithTheBridgeLast() external view {
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions(_l2());

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        _assertL2Actions(actions, _l2());
    }

    function test_buildL2Actions_RevertsWhileAnAddressIsMissing() external {
        for (uint256 i; i < 6; ++i) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL2Actions(_l2WithZero(i));
        }
    }

    /// @dev The DAO executes the L1 actions plus one `sendMessage` that `BuildProposal` appends,
    /// and the fork rehearsal executes exactly this batch. Pins its shape and the message it
    /// carries, decoded from the `sendMessage` calldata rather than rebuilt here.
    function test_buildAllActions_AppendsTheL2MessageAfterTheL1Actions() external view {
        Controller.Action[] memory actions = proposal.exposedBuildAllActions(_l1(), _l2());

        assertEq(actions.length, 7);
        Controller.Action[] memory l1Actions = new Controller.Action[](6);
        for (uint256 i; i < 6; ++i) {
            l1Actions[i] = actions[i];
        }
        _assertL1Actions(l1Actions, _l1());
        assertEq(actions[6].target, L1.BRIDGE);
        assertEq(actions[6].value, 0);

        IBridge.Message memory message = proposal.decodeSendMessage(actions[6].data);
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
            message.data.length, 3076, "L2 message size moved; re-derive the pinned relayer budget"
        );
    }

    /// @dev Pins what the no-argument builders forward. While the constants in `Proposal0025.s.sol`
    /// are placeholders they must refuse to encode; once deployed, the forwarded addresses are
    /// the `DEPLOYED_*` literals above rather than reads of `Proposal0025` or the address
    /// libraries, so an edit to one of those constants cannot be mirrored here.
    function test_buildL1Actions_UsesDeployedImplementations() external {
        if (_placeholdersPending()) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL1Actions();
            return;
        }

        Proposal0025.L1Deployment memory deployed = Proposal0025.L1Deployment({
            bridgeImpl: DEPLOYED_BRIDGE_IMPL_L1,
            erc20VaultImpl: DEPLOYED_ERC20_VAULT_IMPL_L1,
            erc721VaultImpl: DEPLOYED_ERC721_VAULT_IMPL_L1,
            erc1155VaultImpl: DEPLOYED_ERC1155_VAULT_IMPL_L1,
            bridgedErc721Impl: DEPLOYED_BRIDGED_ERC721_L1,
            bridgedErc1155Impl: DEPLOYED_BRIDGED_ERC1155_L1
        });
        _assertNoZero(deployed.bridgeImpl, deployed.erc20VaultImpl, deployed.erc721VaultImpl);
        _assertNoZero(
            deployed.erc1155VaultImpl, deployed.bridgedErc721Impl, deployed.bridgedErc1155Impl
        );
        _assertL1Actions(proposal.exposedBuildL1Actions(), deployed);
    }

    function test_buildL2Actions_UsesDeployedImplementations() external {
        if (_placeholdersPending()) {
            vm.expectRevert(Proposal0025.ImplementationNotDeployed.selector);
            proposal.exposedBuildL2Actions();
            return;
        }

        Proposal0025.L2Deployment memory deployed = Proposal0025.L2Deployment({
            bridgeImpl: DEPLOYED_BRIDGE_IMPL_L2,
            erc20VaultImpl: DEPLOYED_ERC20_VAULT_IMPL_L2,
            erc721VaultImpl: DEPLOYED_ERC721_VAULT_IMPL_L2,
            erc1155VaultImpl: DEPLOYED_ERC1155_VAULT_IMPL_L2,
            bridgedErc721Impl: DEPLOYED_BRIDGED_ERC721_L2,
            bridgedErc1155Impl: DEPLOYED_BRIDGED_ERC1155_L2
        });
        _assertNoZero(deployed.bridgeImpl, deployed.erc20VaultImpl, deployed.erc721VaultImpl);
        _assertNoZero(
            deployed.erc1155VaultImpl, deployed.bridgedErc721Impl, deployed.bridgedErc1155Impl
        );
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions();
        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        _assertL2Actions(actions, deployed);
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
            || proposal.ERC721_VAULT_NEW_IMPL_L1() == address(0)
            || proposal.ERC1155_VAULT_NEW_IMPL_L1() == address(0)
            || proposal.BRIDGE_NEW_IMPL_L2() == address(0)
            || proposal.ERC20_VAULT_NEW_IMPL_L2() == address(0)
            || proposal.ERC721_VAULT_NEW_IMPL_L2() == address(0)
            || proposal.ERC1155_VAULT_NEW_IMPL_L2() == address(0);
    }

    /// @dev The L1 leg: bridge, ERC20 vault, the two bridged-token registrations, then the two
    /// NFT vaults.
    function _assertL1Actions(
        Controller.Action[] memory _actions,
        Proposal0025.L1Deployment memory _d
    )
        internal
        pure
    {
        assertEq(_actions.length, 6);
        _assertUpgrades(_actions[0], L1.BRIDGE, _d.bridgeImpl);
        _assertUpgrades(_actions[1], L1.ERC20_VAULT, _d.erc20VaultImpl);
        _assertRegisters(
            _actions[2], L1.SHARED_RESOLVER, 1, LibNames.B_BRIDGED_ERC721, _d.bridgedErc721Impl
        );
        _assertRegisters(
            _actions[3], L1.SHARED_RESOLVER, 1, LibNames.B_BRIDGED_ERC1155, _d.bridgedErc1155Impl
        );
        _assertUpgrades(_actions[4], L1.ERC721_VAULT, _d.erc721VaultImpl);
        _assertUpgrades(_actions[5], L1.ERC1155_VAULT, _d.erc1155VaultImpl);
    }

    /// @dev The L2 leg: the check that Proposal0024's L2 batch has registered the L1 bridge, the
    /// six resolver entries, the three vaults, then the bridge.
    function _assertL2Actions(
        Controller.Action[] memory _actions,
        Proposal0025.L2Deployment memory _d
    )
        internal
        pure
    {
        assertEq(_actions.length, 11);
        _assertResolves(_actions[0], L2.SHARED_RESOLVER, 1, LibNames.B_BRIDGE);
        _assertRegisters(
            _actions[1], L2.SHARED_RESOLVER, 1, LibNames.B_ERC721_VAULT, L1.ERC721_VAULT
        );
        _assertRegisters(
            _actions[2], L2.SHARED_RESOLVER, 1, LibNames.B_ERC1155_VAULT, L1.ERC1155_VAULT
        );
        _assertRegisters(
            _actions[3], L2.SHARED_RESOLVER, 167_000, LibNames.B_ERC721_VAULT, L2.ERC721_VAULT
        );
        _assertRegisters(
            _actions[4], L2.SHARED_RESOLVER, 167_000, LibNames.B_ERC1155_VAULT, L2.ERC1155_VAULT
        );
        _assertRegisters(
            _actions[5],
            L2.SHARED_RESOLVER,
            167_000,
            LibNames.B_BRIDGED_ERC721,
            _d.bridgedErc721Impl
        );
        _assertRegisters(
            _actions[6],
            L2.SHARED_RESOLVER,
            167_000,
            LibNames.B_BRIDGED_ERC1155,
            _d.bridgedErc1155Impl
        );
        _assertUpgrades(_actions[7], L2.ERC721_VAULT, _d.erc721VaultImpl);
        _assertUpgrades(_actions[8], L2.ERC1155_VAULT, _d.erc1155VaultImpl);
        _assertUpgrades(_actions[9], L2.ERC20_VAULT, _d.erc20VaultImpl);
        _assertUpgrades(_actions[10], L2.BRIDGE, _d.bridgeImpl);
    }

    function _l1() internal pure returns (Proposal0025.L1Deployment memory) {
        return Proposal0025.L1Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L1,
            erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1,
            erc721VaultImpl: ERC721_VAULT_NEW_IMPL_L1,
            erc1155VaultImpl: ERC1155_VAULT_NEW_IMPL_L1,
            bridgedErc721Impl: BRIDGED_ERC721_L1,
            bridgedErc1155Impl: BRIDGED_ERC1155_L1
        });
    }

    function _l2() internal pure returns (Proposal0025.L2Deployment memory) {
        return Proposal0025.L2Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L2,
            erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2,
            erc721VaultImpl: ERC721_VAULT_NEW_IMPL_L2,
            erc1155VaultImpl: ERC1155_VAULT_NEW_IMPL_L2,
            bridgedErc721Impl: BRIDGED_ERC721_L2,
            bridgedErc1155Impl: BRIDGED_ERC1155_L2
        });
    }

    /// @dev `_l1()` with its `_field`-th member, in declaration order, set to zero.
    function _l1WithZero(uint256 _field)
        internal
        pure
        returns (Proposal0025.L1Deployment memory d_)
    {
        d_ = _l1();
        if (_field == 0) d_.bridgeImpl = address(0);
        else if (_field == 1) d_.erc20VaultImpl = address(0);
        else if (_field == 2) d_.erc721VaultImpl = address(0);
        else if (_field == 3) d_.erc1155VaultImpl = address(0);
        else if (_field == 4) d_.bridgedErc721Impl = address(0);
        else d_.bridgedErc1155Impl = address(0);
    }

    /// @dev `_l2()` with its `_field`-th member, in declaration order, set to zero.
    function _l2WithZero(uint256 _field)
        internal
        pure
        returns (Proposal0025.L2Deployment memory d_)
    {
        d_ = _l2();
        if (_field == 0) d_.bridgeImpl = address(0);
        else if (_field == 1) d_.erc20VaultImpl = address(0);
        else if (_field == 2) d_.erc721VaultImpl = address(0);
        else if (_field == 3) d_.erc1155VaultImpl = address(0);
        else if (_field == 4) d_.bridgedErc721Impl = address(0);
        else d_.bridgedErc1155Impl = address(0);
    }

    function _assertNoZero(address _a, address _b, address _c) internal pure {
        assertTrue(
            _a != address(0) && _b != address(0) && _c != address(0),
            "fill in the DEPLOYED_* literals"
        );
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
        address _resolver,
        uint256 _chainId,
        bytes32 _name,
        address _addr
    )
        internal
        pure
    {
        assertEq(_action.target, _resolver);
        assertEq(_action.value, 0);
        assertEq(
            _action.data, abi.encodeCall(DefaultResolver.registerAddress, (_chainId, _name, _addr))
        );
    }

    /// @dev `_action` resolves `_name` for `_chainId` on `_resolver` without allowing the zero
    /// address, so it reverts while the name is unregistered.
    function _assertResolves(
        Controller.Action memory _action,
        address _resolver,
        uint256 _chainId,
        bytes32 _name
    )
        internal
        pure
    {
        assertEq(_action.target, _resolver);
        assertEq(_action.value, 0);
        assertEq(_action.data, abi.encodeCall(IResolver.resolve, (_chainId, _name, false)));
    }
}
