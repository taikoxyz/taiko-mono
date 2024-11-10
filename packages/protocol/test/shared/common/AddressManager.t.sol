// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
/// @author Daniel Wang <dan@taiko.xyz>
contract TestAddressManager is CommonTest {

    uint public constant chainId = 123;

    function test_registerAddress() external transactBy(deployer) {
        vm.expectEmit(address(resolver));
        emit AddressManager.AddressRegistered(chainId, "Friend", Bob, address(0));
        resolver.registerAddress(chainId, "Friend", Bob);

        assertEq(resolver.resolve(chainId, "Friend", false), Bob, "should return Bob address");
        assertEq(resolver.resolve(chainId, "Friend", true), Bob, "should return Bob address");


       vm.expectEmit(address(resolver));
        emit AddressManager.AddressRegistered(chainId, "Friend", Alice, Bob);
        resolver.registerAddress(chainId, "Friend", Alice);

            assertEq(resolver.resolve(chainId, "Friend", false), Alice, "should return Alice address");
        assertEq(resolver.resolve(chainId, "Friend", true), Alice, "should return Alice address");
    }

    function test_registerAddress_callerNotOwner() external transactBy(Alice) {
        vm.expectRevert("Ownable: caller is not the owner");
        resolver.registerAddress(chainId, "Stranger", Bob);
    }

    function test_getAddress_unregistered_address() external {
        vm.expectRevert(IResolver.RESOLVED_TO_ZERO_ADDRESS.selector);
        resolver.resolve(chainId, "Enemy", false);

        assertEq(resolver.resolve(chainId, "Enemy", true), address(0), "should return 0 address");
    }
}
