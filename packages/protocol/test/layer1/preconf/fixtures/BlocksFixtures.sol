// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BaseTest.sol";
import "../mocks/MockPreconfRegistry.sol";
import "../mocks/MockPreconfServiceManager.sol";
import "../mocks/MockBeaconBlockRoot.sol";
import "test/layer1/based/stubs/TaikoL1Stub.sol";

import "src/layer1/preconf/impl/LibPreconfConstants.sol";
import "src/layer1/preconf/impl/PreconfTaskManager.sol";
import "src/layer1/preconf/iface/IPreconfRegistry.sol";
import "src/layer1/preconf/iface/IPreconfServiceManager.sol";
import "src/layer1/preconf/iface/IPreconfTaskManager.sol";

contract BlocksFixtures is BaseTest {
    PreconfTaskManager internal preconfTaskManager;
    MockPreconfRegistry internal preconfRegistry;
    MockPreconfServiceManager internal preconfServiceManager;
    MockBeaconBlockRoot internal beaconBlockRootContract;
    TaikoL1Stub internal taikoL1;

    function setUp() public virtual {
        preconfRegistry = new MockPreconfRegistry();
        preconfServiceManager = new MockPreconfServiceManager();
        beaconBlockRootContract = new MockBeaconBlockRoot();
        taikoL1 = new TaikoL1Stub();

        preconfTaskManager = new PreconfTaskManager(
            IPreconfServiceManager(address(preconfServiceManager)),
            IPreconfRegistry(address(preconfRegistry)),
            ITaikoL1(taikoL1),
            LibPreconfConstants.MAINNET_BEACON_GENESIS,
            address(beaconBlockRootContract)
        );
    }

    /// @dev Inserts two preconfers in the lookahead for the next epoch at the given slots.
    function prepareLookahead(uint256 slot1, uint256 slot2) internal {
        addPreconfersToRegistry(3);

        uint256 nextEpochStart =
            LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_EPOCH;

        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](2);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_1,
            timestamp: nextEpochStart + LibPreconfConstants.SECONDS_IN_SLOT * (slot1 - 1)
        });
        lookaheadSetParams[1] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_3,
            timestamp: nextEpochStart + LibPreconfConstants.SECONDS_IN_SLOT * (slot2 - 1)
        });

        vm.warp(LibPreconfConstants.MAINNET_BEACON_GENESIS + LibPreconfConstants.SECONDS_IN_SLOT);
        vm.prank(addr_1);
        preconfTaskManager.forcePushLookahead(lookaheadSetParams);
    }

    function addPreconfersToRegistry(uint256 count) internal {
        for (uint256 i = 1; i <= count; i++) {
            preconfRegistry.registerPreconfer(vm.addr(i));
        }
    }
}
