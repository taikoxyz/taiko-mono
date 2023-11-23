// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "forge-std/Test.sol";
import "../../contracts/common/EssentialContract.sol";

contract Target1 is EssentialContract {
    uint256 public count;

    function init() external initializer {
        EssentialContract._init(address(0));
        count = 100;
    }

    function adjust() external onlyOwner {
        count += 1;
    }
}

contract EssentialContractTest is Test {
    address Alice = vm.addr(1);
    address Bob = vm.addr(2);
    address Cindy = vm.addr(3);

    // This tests shows that the admin() and owner() cannot be the same, otherwise,
    // the owner cannot transact delegated functions on implementation.
    function test_essential_behind_transparent_proxy() external {
        bytes memory data = bytes.concat(Target1.init.selector);
        vm.startPrank(Alice);
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(new Target1()), Bob, data);
        Target1 target = Target1(address(proxy));
        vm.stopPrank();

        // Owner is Alice
        // Admin is Bob

        vm.prank(Cindy);
        assertEq(target.owner(), Alice);

        // Only Bob can call admin()
        vm.prank(Bob);
        assertEq(proxy.admin(), Bob);

        // Other people, including Alice, cannot call admin()
        vm.prank(Alice);
        vm.expectRevert();
        proxy.admin();

        vm.prank(Cindy);
        vm.expectRevert();
        proxy.admin();

        // Alice can adjust();
        vm.prank(Alice);
        target.adjust();
        assertEq(target.count(), 101);

        // Bob cannot adjust()
        vm.prank(Bob);
        vm.expectRevert();
        target.adjust();

        // Transfer Owner to Bob, so Bob is both admin and owner
        vm.prank(Alice);
        target.transferOwnership(Bob);

        vm.prank(Cindy);
        assertEq(target.owner(), Bob);

        // Now Bob cannot call adjust()
        vm.prank(Bob);
        vm.expectRevert();
        target.adjust();
    }
}
