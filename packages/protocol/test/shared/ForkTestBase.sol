// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CommonTest.sol";

/// @title ForkTestBase
/// @notice Base contract for fork testing
/// @dev Each test gets a fresh copy of state after setUp(), so fork IDs
/// created in setUp() can be reused within a single test via selectFork()
abstract contract ForkTestBase is CommonTest {
    // Fork IDs - created once in setUp() if needed
    uint256 internal mainnetFork;

    // RPC URL environment variable name
    string constant MAINNET_RPC_KEY = "MAINNET_RPC_URL";

    /// @notice Modifier to skip tests when mainnet RPC URL is not available
    modifier requiresMainnetFork() {
        try vm.envString(MAINNET_RPC_KEY) returns (string memory) {
            _;
        } catch {
            console2.log("Skipping test: MAINNET_RPC_URL not set");
            vm.skip(true);
        }
    }

    /// @notice Create a mainnet fork at a specific block
    /// @dev Call this in setUp() if your tests need a mainnet fork
    /// @param blockNumber The block number to fork at
    function _createMainnetFork(uint256 blockNumber) internal requiresMainnetFork {
        string memory rpcUrl = vm.envString(MAINNET_RPC_KEY);
        mainnetFork = vm.createFork(rpcUrl, blockNumber);
    }

    /// @notice Create a mainnet fork at latest block
    /// @dev Call this in setUp() if your tests need a mainnet fork
    function _createMainnetFork() internal requiresMainnetFork {
        string memory rpcUrl = vm.envString(MAINNET_RPC_KEY);
        mainnetFork = vm.createFork(rpcUrl);
    }

    /// @notice Select the mainnet fork
    /// @dev Use this in tests to switch to the mainnet fork created in setUp()
    function _selectMainnetFork() internal {
        vm.selectFork(mainnetFork);
    }
}
