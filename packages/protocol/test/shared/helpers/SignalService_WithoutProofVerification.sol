// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/SignalService.sol";

contract SignalService_WithoutProofVerification is SignalService {
    constructor(address _resolver) SignalService(_resolver) { }

    function _verifyProof(
        uint64, /*chainId*/
        address, /*app*/
        bytes32, /*signal*/
        bytes32, /*value*/
        Proof memory, /*hop*/
        address /*relay*/
    )
        internal
        pure
        override
        returns (bytes32)
    {
        // Skip verifying the merkle proof entirely
        return bytes32(uint256(789));
    }

    /// @notice Override to skip all signal verification for testing
    function verifySignalReceived(
        uint64,  /*_chainId*/
        address, /*_app*/
        bytes32, /*_signal*/
        bytes calldata /*_proof*/
    )
        external
        pure
        override
    {
        // Skip all verification for testing - just return without reverting
        return;
    }
}
