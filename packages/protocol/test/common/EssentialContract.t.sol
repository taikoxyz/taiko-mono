// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract Target1 is EssentialContract {
    uint256 public count;

    function init() external initializer {
        __Essential_init();
        count = 100;
    }

    function adjust() external virtual onlyOwner {
        count += 1;
    }
}

contract Target2 is Target1 {
    function update() external onlyOwner {
        count += 10;
    }

    function adjust() external override onlyOwner {
        count -= 1;
    }
}

contract TestOwnerUUPSUpgradable is TaikoTest {
    /// @dev This is how we can query the admin - because from v.4.9.5 external admin() function
    /// does not exist anymore.
    bytes32 internal constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function test_essential_behind_1967_proxy() external {
        bytes memory data = abi.encodeCall(Target1.init, ());
        vm.startPrank(Alice);
        ERC1967Proxy proxy = new ERC1967Proxy(address(new Target1()), data);
        Target1 target = Target1(address(proxy));
        vm.stopPrank();

        // Owner is Alice
        vm.prank(Carol);
        assertEq(target.owner(), Alice);

        // Alice can adjust();
        vm.prank(Alice);
        target.adjust();
        assertEq(target.count(), 101);

        // Bob cannot adjust()
        vm.prank(Bob);
        vm.expectRevert();
        target.adjust();

        address v2 = address(new Target2());
        data = abi.encodeCall(Target2.update, ());

        vm.prank(Bob);
        vm.expectRevert();
        target.upgradeToAndCall(v2, data);

        vm.prank(Alice);
        target.upgradeToAndCall(v2, data);
        assertEq(target.count(), 111);

        vm.prank(Alice);
        target.adjust();
        assertEq(target.count(), 110);
    }

    // This tests shows that the admin() and owner() cannot be the same, otherwise,
    // the owner cannot transact delegated functions on implementation.
    function test_essential_behind_transparent_proxy() external {
        bytes memory data = abi.encodeCall(Target1.init, ());
        vm.startPrank(Alice);
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(new Target1()), Bob, data);
        Target1 target = Target1(address(proxy));
        vm.stopPrank();

        // Owner is Alice
        // Admin is Bob

        vm.prank(Carol);
        assertEq(target.owner(), Alice);

        // Admin can be queried via storage slot only - no other way.
        bytes32 adminSlotValue = vm.load(address(proxy), _ADMIN_SLOT);
        address admin = address(uint160(uint256(adminSlotValue)));
        assertEq(admin, Bob);

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

        vm.prank(Carol);
        assertEq(target.owner(), Bob);

        // Now Bob cannot call adjust()
        vm.prank(Bob);
        vm.expectRevert();
        target.adjust();
    }
}
