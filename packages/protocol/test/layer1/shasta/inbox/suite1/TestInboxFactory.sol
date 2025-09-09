// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestInboxCore.sol";
import "./TestInboxOptimized1.sol";
import "./TestInboxOptimized2.sol";
import "./TestInboxOptimized3.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title TestInboxFactory
/// @notice Factory contract to deploy different Inbox implementations for testing
/// @custom:security-contact security@taiko.xyz
contract TestInboxFactory {
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
        // Create mock dependencies
        address bondToken = address(new MockERC20());
        address checkpointManager = address(new StubCheckpointManager());
        address proofVerifier = address(new StubProofVerifier());

        return deployInboxWithMocks(
            _type, _owner, _genesisBlockHash, bondToken, checkpointManager, proofVerifier
        );
    }

    /// @notice Deploy a specific Inbox implementation with custom mock addresses
    /// @param _type The type of Inbox to deploy
    /// @param _owner The owner of the deployed contract
    /// @param _genesisBlockHash The genesis block hash for initialization
    /// @param _bondToken The bond token mock address
    /// @param _checkpointManager The checkpoint manager mock address
    /// @param _proofVerifier The proof verifier mock address
    /// @return inbox The deployed Inbox proxy address
    function deployInboxWithMocks(
        InboxType _type,
        address _owner,
        bytes32 _genesisBlockHash,
        address _bondToken,
        address _checkpointManager,
        address _proofVerifier
    )
        public
        returns (address inbox)
    {
        address impl;

        if (_type == InboxType.Base) {
            impl = address(new TestInboxCore(_bondToken, _checkpointManager, _proofVerifier));
        } else if (_type == InboxType.Optimized1) {
            impl = address(new TestInboxOptimized1(_bondToken, _checkpointManager, _proofVerifier));
        } else if (_type == InboxType.Optimized2) {
            impl = address(new TestInboxOptimized2(_bondToken, _checkpointManager, _proofVerifier));
        } else if (_type == InboxType.Optimized3) {
            impl = address(new TestInboxOptimized3(_bondToken, _checkpointManager, _proofVerifier));
        } else {
            revert("Invalid inbox type");
        }

        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initV3(address,bytes32)")), _owner, _genesisBlockHash
        );

        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        inbox = address(proxy);
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
