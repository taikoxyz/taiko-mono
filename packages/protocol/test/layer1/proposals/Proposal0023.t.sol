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

    /// @dev Replace, do not delete, this test when the real deployed addresses land: assert that
    /// the no-argument overloads forward those constants in the correct argument order. Both L2
    /// parameters are `address`, so a transposition compiles silently and nothing else here
    /// catches it. See `test_buildL1Actions_UsesDeployedImplementations` in `Proposal0017.t.sol`.
    function test_placeholderConstantsStillGuardTheBuilders() external {
        Proposal0023Harness proposal = new Proposal0023Harness();

        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions();

        vm.expectRevert(Proposal0023.ImplementationNotDeployed.selector);
        proposal.exposedBuildL2Actions();
    }
}

contract Proposal0023Harness is Proposal0023 {
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
