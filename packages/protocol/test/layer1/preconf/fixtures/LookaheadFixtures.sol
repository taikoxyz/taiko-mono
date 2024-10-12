// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer1/based/MockTaikoL1.sol";
import "src/layer1/preconf/impl/PreconfConstants.sol";
import "src/layer1/preconf/impl/PreconfTaskManager.sol";
import "src/layer1/preconf/iface/IPreconfRegistry.sol";
import "src/layer1/preconf/iface/IPreconfServiceManager.sol";

import "../BaseTest.sol";
import "../mocks/MockPreconfRegistry.sol";
import "../mocks/MockPreconfServiceManager.sol";
import "../mocks/MockBeaconBlockRoot.sol";



contract LookaheadFixtures is BaseTest {
    PreconfTaskManager internal preconfTaskManager;
    MockPreconfRegistry internal preconfRegistry;
    MockPreconfServiceManager internal preconfServiceManager;
    MockBeaconBlockRoot internal beaconBlockRootContract;
    MockTaikoL1 internal taikoL1;

    function setUp() public virtual {
        preconfRegistry = new MockPreconfRegistry();
        preconfServiceManager = new MockPreconfServiceManager();
        beaconBlockRootContract = new MockBeaconBlockRoot();
        taikoL1 = new MockTaikoL1();

        preconfTaskManager = new PreconfTaskManager(
            IPreconfServiceManager(address(preconfServiceManager)),
            IPreconfRegistry(address(preconfRegistry)),
            ITaikoL1(taikoL1),
            PreconfConstants.MAINNET_BEACON_GENESIS,
            address(beaconBlockRootContract)
        );
    }

    function addPreconfersToRegistry(uint256 count) internal {
        for (uint256 i = 1; i <= count; i++) {
            preconfRegistry.registerPreconfer(vm.addr(i));
        }
    }

    function computeFallbackPreconfer(
        bytes32 randomness,
        uint256 nextPreconferIndex
    )
        internal
        pure
        returns (address)
    {
        return vm.addr(uint256(randomness) % (nextPreconferIndex - 1) + 1);
    }
}
