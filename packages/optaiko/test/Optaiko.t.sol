// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Optaiko} from "../contracts/Optaiko.sol";
import {IOptaiko} from "../contracts/IOptaiko.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title OptaikoTest
/// @notice Test suite for Optaiko contract
contract OptaikoTest is Test {
    Optaiko public optaikoImplementation;
    Optaiko public optaiko;
    address public poolManager;
    address public owner;
    address public user1;

    function setUp() public {
        // Setup test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        poolManager = makeAddr("poolManager");

        // Deploy implementation
        optaikoImplementation = new Optaiko();

        // Deploy proxy and initialize
        bytes memory initData =
            abi.encodeWithSelector(Optaiko.initialize.selector, poolManager, owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(optaikoImplementation), initData);
        optaiko = Optaiko(address(proxy));
    }

    /// @notice Test deployment and initialization
    function testDeploy() public view {
        assertEq(address(optaiko.poolManager()), poolManager, "Pool manager not set correctly");
        assertEq(optaiko.owner(), owner, "Owner not set correctly");
    }

    /// @notice Test minting a basic option
    function testMintOption() public {
        vm.startPrank(user1);

        // Create a simple long call option leg
        IOptaiko.Leg[] memory legs = new IOptaiko.Leg[](1);
        legs[0] = IOptaiko.Leg({
            isLong: true,
            tickLower: -60,
            tickUpper: 60,
            liquidity: 1000e18
        });

        bytes32 poolId = keccak256("test_pool");

        // Mint the option
        uint256 positionId = optaiko.mintOption(poolId, legs);

        // Verify position was created
        assertEq(positionId, 1, "Position ID should be 1");

        // Get position details
        IOptaiko.OptionPosition memory position = optaiko.getPosition(positionId);

        assertEq(position.owner, user1, "Position owner incorrect");
        assertEq(position.poolId, poolId, "Pool ID incorrect");
        assertEq(position.legs.length, 1, "Should have 1 leg");
        assertEq(position.legs[0].isLong, true, "Leg should be long");
        assertEq(position.legs[0].tickLower, -60, "Tick lower incorrect");
        assertEq(position.legs[0].tickUpper, 60, "Tick upper incorrect");

        vm.stopPrank();
    }

    /// @notice Test burning an option
    function testBurnOption() public {
        vm.startPrank(user1);

        // Create and mint a position
        IOptaiko.Leg[] memory legs = new IOptaiko.Leg[](1);
        legs[0] = IOptaiko.Leg({
            isLong: false,
            tickLower: -120,
            tickUpper: 120,
            liquidity: 500e18
        });

        bytes32 poolId = keccak256("test_pool");
        uint256 positionId = optaiko.mintOption(poolId, legs);

        // Burn the position
        optaiko.burnOption(positionId);

        // Position should no longer exist
        vm.expectRevert();
        optaiko.getPosition(positionId);

        vm.stopPrank();
    }

    /// @notice Test multi-leg position (spread)
    function testMultiLegPosition() public {
        vm.startPrank(user1);

        // Create a bull call spread (long lower strike, short higher strike)
        IOptaiko.Leg[] memory legs = new IOptaiko.Leg[](2);
        legs[0] = IOptaiko.Leg({
            isLong: true,
            tickLower: -60,
            tickUpper: 0,
            liquidity: 1000e18
        });
        legs[1] = IOptaiko.Leg({
            isLong: false,
            tickLower: 0,
            tickUpper: 60,
            liquidity: 1000e18
        });

        bytes32 poolId = keccak256("test_pool");
        uint256 positionId = optaiko.mintOption(poolId, legs);

        IOptaiko.OptionPosition memory position = optaiko.getPosition(positionId);

        assertEq(position.legs.length, 2, "Should have 2 legs");
        assertEq(position.legs[0].isLong, true, "First leg should be long");
        assertEq(position.legs[1].isLong, false, "Second leg should be short");

        vm.stopPrank();
    }

    /// @notice Test upgradeability
    function testUpgrade() public {
        // Deploy new implementation
        Optaiko newImplementation = new Optaiko();

        // Upgrade (as owner)
        vm.prank(owner);
        optaiko.upgradeToAndCall(address(newImplementation), "");

        // Verify state is preserved
        assertEq(address(optaiko.poolManager()), poolManager, "Pool manager changed after upgrade");
        assertEq(optaiko.owner(), owner, "Owner changed after upgrade");
    }

    /// @notice Test unauthorized upgrade attempt
    function testUnauthorizedUpgrade() public {
        Optaiko newImplementation = new Optaiko();

        // Should revert when non-owner tries to upgrade
        vm.prank(user1);
        vm.expectRevert();
        optaiko.upgradeToAndCall(address(newImplementation), "");
    }

    /// @notice Test updating pool manager
    function testUpdatePoolManager() public {
        address newPoolManager = makeAddr("newPoolManager");

        vm.prank(owner);
        optaiko.updatePoolManager(newPoolManager);

        assertEq(address(optaiko.poolManager()), newPoolManager, "Pool manager not updated");
    }
}
