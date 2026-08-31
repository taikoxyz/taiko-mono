// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract TestBridge2_receive is TestBridge2Base {
    function getPauser() internal override returns (address) {
        return Alice;
    }

    function test_bridge2_receive_pauser_funds_via_call()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        uint256 bridgeBalanceBefore = address(eBridge).balance;

        (bool ok,) = address(eBridge).call{ value: 1 ether }("");

        assertTrue(ok);
        assertEq(address(eBridge).balance, bridgeBalanceBefore + 1 ether);
    }

    function test_bridge2_receive_pauser_zero_value()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        uint256 bridgeBalanceBefore = address(eBridge).balance;

        (bool ok,) = address(eBridge).call{ value: 0 }("");

        assertTrue(ok);
        assertEq(address(eBridge).balance, bridgeBalanceBefore);
    }

    function test_bridge2_receive_RevertWhen_sender_is_not_pauser()
        public
        transactBy(Bob)
        assertSameTotalBalance
    {
        // Bob is not the pauser, so a plain Ether transfer must be rejected.
        (bool ok, bytes memory ret) = address(eBridge).call{ value: 1 ether }("");

        assertFalse(ok);
        assertEq(bytes4(ret), Bridge.B_PERMISSION_DENIED.selector);
    }

    function test_bridge2_receive_RevertWhen_pauser_uses_transfer()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        // Even the pauser cannot use `transfer`: the bridge runs behind an ERC1967 proxy and the
        // 2300-gas stipend is insufficient for the proxy's delegatecall, so funding must use
        // `call`.
        vm.expectRevert();
        payable(address(eBridge)).transfer(1 ether);
    }
}
