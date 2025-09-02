// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestInboxCore.sol";
import "./TestInboxOptimized1.sol";
import "./TestInboxOptimized2.sol";
import "./TestInboxOptimized3.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";

/// @title TestInboxFactory
/// @notice Factory contract to deploy different Inbox implementations for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxFactory is Test {
    /// @notice The type of Inbox implementation to deploy
    enum InboxType {
        Base,
        Optimized1,
        Optimized2,
        Optimized3
    }

    /// @notice Deploy a specific Inbox implementation
    /// @param _type The type of Inbox to deploy
    /// @param _owner The owner of the deployed contract
    /// @param _genesisBlockHash The genesis block hash for initialization
    /// @return inbox The deployed Inbox proxy address
    function deployInbox(
        InboxType _type,
        address _owner,
        bytes32 _genesisBlockHash
    )
        external
        returns (address inbox)
    {
        address impl;

        if (_type == InboxType.Base) {
            impl = address(new TestInboxCore());
        } else if (_type == InboxType.Optimized1) {
            impl = address(new TestInboxOptimized1());
        } else if (_type == InboxType.Optimized2) {
            impl = address(new TestInboxOptimized2());
        } else if (_type == InboxType.Optimized3) {
            impl = address(new TestInboxOptimized3());
        } else {
            revert("Invalid inbox type");
        }

        bytes memory initData = abi.encodeWithSelector(bytes4(keccak256("init(address)")), _owner);

        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        inbox = address(proxy);

        // Initialize with genesis block hash (must be called as owner)
        vm.prank(_owner);
        Inbox(inbox).init2(_genesisBlockHash);
    }

    /// @notice Get the InboxType from environment variable or default
    /// @dev This is a helper for tests to determine which implementation to use
    function getInboxTypeFromEnv() external pure returns (InboxType) {
        // Note: Solidity cannot directly read environment variables
        // Tests will need to handle this at the test level using vm.envOr
        // This function is here for documentation and can be overridden
        return InboxType.Base;
    }
}
