// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0023 } from "script/layer1/proposals/Proposal0023.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0023Test is Test {
    address internal constant BRIDGE_NEW_IMPL_L1 = 0x1010101010101010101010101010101010101010;
    address internal constant BRIDGE_NEW_IMPL_L2 = 0x2020202020202020202020202020202020202020;
    address internal constant L2_SHARED_RESOLVER = 0x3030303030303030303030303030303030303030;

    // The real deployed addresses, written out so a transposed forward in Proposal0023 cannot be
    // mirrored by reading its own constants back.
    address internal constant DEPLOYED_BRIDGE_IMPL_L1 = 0xA15dca0A72da684f20e0FC708DECFb230a715462;
    address internal constant DEPLOYED_BRIDGE_IMPL_L2 = 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb;
    address internal constant DEPLOYED_L2_SHARED_RESOLVER =
        0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984;

    function test_buildL1Actions_EncodesBridgeUpgrade() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

        Controller.Action[] memory actions = proposal.exposedBuildL1Actions(BRIDGE_NEW_IMPL_L1);

        assertEq(actions.length, 1);
        assertEq(actions[0].target, L1.BRIDGE);
        assertEq(actions[0].value, 0);
        assertEq(actions[0].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (BRIDGE_NEW_IMPL_L1)));
    }

    function test_buildL2Actions_RegistersBothBridgeNamesBeforeUpgrading() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions(L2_SHARED_RESOLVER, BRIDGE_NEW_IMPL_L2);

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 3);

        assertEq(actions[0].target, L2_SHARED_RESOLVER);
        assertEq(actions[0].value, 0);
        assertEq(
            actions[0].data,
            abi.encodeCall(
                DefaultResolver.registerAddress, (uint256(1), LibNames.B_BRIDGE, L1.BRIDGE)
            )
        );

        assertEq(actions[1].target, L2_SHARED_RESOLVER);
        assertEq(actions[1].value, 0);
        assertEq(
            actions[1].data,
            abi.encodeCall(
                DefaultResolver.registerAddress, (uint256(167_000), LibNames.B_BRIDGE, L2.BRIDGE)
            )
        );

        assertEq(actions[2].target, L2.BRIDGE);
        assertEq(actions[2].value, 0);
        assertEq(actions[2].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (BRIDGE_NEW_IMPL_L2)));
    }

    /// @dev Pins what the no-argument builders forward. The two tests above call the
    /// parameterised overloads directly and so bypass the forwarding lines entirely; both
    /// `buildL2Actions` parameters are `address`, so a transposed pair compiles silently and
    /// nothing else in this suite would catch it. The expected addresses are written as literals
    /// rather than read back from `Proposal0023`, so a transposition in the source cannot be
    /// mirrored here. Mirrors `test_buildL1Actions_UsesDeployedImplementations` in
    /// `Proposal0017.t.sol`.
    function test_buildL1Actions_UsesDeployedImplementations() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

        Controller.Action[] memory actions = proposal.exposedBuildL1Actions();

        assertEq(actions.length, 1);
        assertEq(actions[0].target, L1.BRIDGE);
        assertEq(
            actions[0].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (DEPLOYED_BRIDGE_IMPL_L1))
        );
    }

    function test_buildL2Actions_UsesDeployedImplementations() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions();

        assertEq(executionId, 0);
        assertEq(gasLimit, 5_000_000);
        assertEq(actions.length, 3);

        // A transposed forward would put the bridge implementation here and hand the resolver
        // proxy to upgradeTo below, so these two assertions catch it from both ends.
        assertEq(actions[0].target, DEPLOYED_L2_SHARED_RESOLVER);
        assertEq(actions[1].target, DEPLOYED_L2_SHARED_RESOLVER);

        assertEq(actions[2].target, L2.BRIDGE);
        assertEq(
            actions[2].data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (DEPLOYED_BRIDGE_IMPL_L2))
        );
    }

    /// @dev `Proposal0023.action.md` is the payload the DAO actually executes, and it is generated
    /// out-of-band by `P=0023 pnpm proposal`. Nothing else in the repository checks that it was
    /// regenerated after the proposal changed, so a stale file would present one set of actions
    /// for review while the code describes another. This compares the committed calldata against
    /// what `_buildAllActions` builds right now — including the bridge message that wraps the L2
    /// batch, which no other test covers.
    function test_actionFileMatchesTheBuiltCalldata() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

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
}

contract Proposal0023Harness is Proposal0023 {
    function exposedBuildAllActions() external pure returns (Controller.Action[] memory) {
        return _buildAllActions();
    }

    function exposedBuildL1Actions() external pure returns (Controller.Action[] memory) {
        return buildL1Actions();
    }

    function exposedBuildL1Actions(address _bridgeNewImplL1)
        external
        pure
        returns (Controller.Action[] memory)
    {
        return buildL1Actions(_bridgeNewImplL1);
    }

    function exposedBuildL2Actions()
        external
        pure
        returns (uint64, uint32, Controller.Action[] memory)
    {
        return buildL2Actions();
    }

    function exposedBuildL2Actions(
        address _l2SharedResolver,
        address _bridgeNewImplL2
    )
        external
        pure
        returns (uint64, uint32, Controller.Action[] memory)
    {
        return buildL2Actions(_l2SharedResolver, _bridgeNewImplL2);
    }
}
