// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/SignalService.sol";

/// @notice Test helper that bypasses proof verification
/// @dev Note: The new SignalService requires immutable constructor parameters.
///      For tests that need a SignalService without proof verification,
///      this mock provides empty implementations of verification methods.
contract SignalService_WithoutProofVerification is SignalService {
    constructor(address _resolver)
        SignalService(
            address(uint160(uint256(keccak256("MOCK_INBOX")))), // Mock inbox address
            address(uint160(uint256(keccak256("MOCK_REMOTE_SS")))) // Mock remote signal service
        )
    { }

    function proveSignalReceived(
        uint64, /*srcChainId*/
        address, /*app*/
        bytes32, /*signal*/
        bytes calldata /*proof*/
    )
        public
        pure
        override
        returns (uint256)
    {
        // Skip proof verification for testing
        return 0;
    }

    function verifySignalReceived(
        uint64, /*srcChainId*/
        address, /*app*/
        bytes32, /*signal*/
        bytes calldata /*proof*/
    )
        public
        pure
        override
    {
        // Skip proof verification for testing
    }
}
