// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { AnchorForkRouter, IPacayaAnchorLegacy } from "src/layer2/core/AnchorForkRouter.sol";

contract AnchorForkRouterTest is Test {
    AnchorForkRouter private router;

    function setUp() public {
        router = new AnchorForkRouter(address(0x1), address(0x2));
    }

    function test_shouldRouteLegacySelectors() public view {
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.anchorV3.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.getBasefeeV2.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.getBlockHash.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.skipFeeCheck.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.publicInputHash.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.parentGasExcess.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.lastSyncedBlock.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.parentTimestamp.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.parentGasTarget.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.signalService.selector));
        assertTrue(router.shouldRouteToOldFork(IPacayaAnchorLegacy.pacayaForkHeight.selector));
    }

    function test_shouldNotRouteNonLegacySelectors() public view {
        assertFalse(router.shouldRouteToOldFork(bytes4(keccak256("withdraw(address,address)"))));
        assertFalse(router.shouldRouteToOldFork(bytes4(keccak256("getProposalState()"))));
        assertFalse(router.shouldRouteToOldFork(bytes4(keccak256("init(address)"))));
    }
}
