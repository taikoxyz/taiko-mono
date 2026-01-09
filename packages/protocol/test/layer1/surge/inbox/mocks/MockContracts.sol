// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockSurgeVerifier {
    function verifyProof(bool, bytes32, bytes calldata) external pure returns (uint8) {
        return 1; // Return a non-zero bitmap to pass threshold checks
    }
}

contract MockProofVerifier {
    function verifyProof(uint256, bytes32, bytes calldata) external pure { }
}
