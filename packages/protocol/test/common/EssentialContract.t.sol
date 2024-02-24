// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract Target1 is Essential1StepContract {
    uint256 public count;

    function init() external initializer {
        __Essential_init();
        count = 100;
    }

    function adjust() external virtual onlyOwner {
        count += 1;
    }
}
/// @title Target1
/// @dev Implements Essential1StepContract and provides functionality to manage a count variable.
contract Target1 is Essential1StepContract {
    /// @dev Initialize count to 100
    uint256 public count = 100;

    /// @dev Adjusts the count by adding 1, only accessible by the owner.
    function adjust() external virtual onlyOwner {
        count += 1;
    }
}

/// @title Target2
/// @dev Extends Target1 and provides additional functionality to manage the count variable.
contract Target2 is Target1 {
    /// @dev Updates the count by adding 10, only accessible by the owner.
    function update() external onlyOwner {
        count += 10;
    }

    /// @dev Adjusts the count by subtracting 1, only accessible by the owner.
    function adjust() external override onlyOwner {
        count -= 1;
    }
}

/// @title TestOwnerUUPSUpgradable
/// @dev Implements tests for the functionality provided by Target1 and Target2 contracts.
contract TestOwnerUUPSUpgradable is TaikoTest {
    /// @dev Tests the functionality behind ERC1967 proxy.
    function test_essential_behind_1967_proxy() external {
        // Test implementation behind ERC1967 proxy
        bytes memory data = abi.encodeWithSelector(Target1.adjust.selector);
        //...
    }

    /// @dev Tests the functionality behind transparent proxy.
    function test_essential_behind_transparent_proxy() external {
        // Test implementation behind transparent proxy
        bytes memory data = abi.encodeWithSelector(Target2.adjust.selector);
        //...
    }
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

        // Only Bob can call admin()
        vm.prank(Bob);
        assertEq(proxy.admin(), Bob);

        // Other people, including Alice, cannot call admin()
        vm.prank(Alice);
        vm.expectRevert();
        proxy.admin();

        vm.prank(Carol);
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

        vm.prank(Carol);
        assertEq(target.owner(), Bob);

        // Now Bob cannot call adjust()
        vm.prank(Bob);
        vm.expectRevert();
        target.adjust();
    }
}
