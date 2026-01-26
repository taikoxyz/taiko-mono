// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @custom:security-contact security@taiko.xyz

interface IShadow {
    struct PublicInput {
        uint48 blockNumber;
        bytes32 stateRoot;
        uint256 chainId;
        uint256 noteIndex;
        uint256 amount;
        address recipient;
        bytes32 nullifier;
        bytes32 powDigest;
    }

    event Claimed(bytes32 indexed nullifier, address indexed recipient, uint256 amount);

    error ChainIdMismatch(uint256 expected, uint256 actual);
    error InvalidAmount(uint256 amount);
    error InvalidPowDigest(bytes32 powDigest);
    error InvalidRecipient(address recipient);
    error NullifierAlreadyConsumed(bytes32 nullifier);
    error ProofVerificationFailed();

    /// @notice Submits a proof and public inputs to mint ETH.
    function claim(bytes calldata _proof, PublicInput calldata _input) external;
}
