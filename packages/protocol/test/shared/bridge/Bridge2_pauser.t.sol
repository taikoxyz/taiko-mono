// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/common/EssentialContract.sol";

contract TestBridgePauser is CommonTest {
    SignalService internal eSignalService;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_E")))), deployer
        );
    }

    function test_bridge_pause_byDesignatedPauser() public {
        Bridge bridge = _deployBridgeWithPauser(Alice);

        vm.prank(Alice);
        bridge.pause();
        assertTrue(bridge.paused());

        vm.prank(Alice);
        bridge.unpause();
        assertFalse(bridge.paused());
    }

    function test_bridge_pause_byOwner_stillWorks() public {
        Bridge bridge = _deployBridgeWithPauser(Alice);

        vm.prank(deployer);
        bridge.pause();
        assertTrue(bridge.paused());

        vm.prank(deployer);
        bridge.unpause();
        assertFalse(bridge.paused());
    }

    function test_bridge_pause_RevertWhen_notOwnerOrPauser() public {
        Bridge bridge = _deployBridgeWithPauser(Alice);

        vm.prank(Bob);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        bridge.pause();
    }

    function test_bridge_pause_RevertWhen_zeroPauser_nonOwner() public {
        Bridge bridge = _deployBridgeWithPauser(address(0));

        vm.prank(Alice);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        bridge.pause();
    }

    function _deployBridgeWithPauser(address pauser) private returns (Bridge) {
        Bridge impl = new Bridge(address(resolver), address(eSignalService), pauser);
        return Bridge(
            payable(address(
                    new ERC1967Proxy(address(impl), abi.encodeCall(Bridge.init, (deployer)))
                ))
        );
    }
}
