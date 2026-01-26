// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IShadow
/// @notice Enables private ETH claims using zero-knowledge proofs.
/// @custom:security-contact security@taiko.xyz
interface IShadow {
    /// @notice Public inputs for proof verification.
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

    /// @notice Emitted when ETH is claimed.
    event Claimed(bytes32 indexed nullifier, address indexed recipient, uint256 amount);

    error ChainIdMismatch(uint256 expected, uint256 actual);
    error InvalidAmount(uint256 amount);
    error InvalidPowDigest(bytes32 powDigest);
    error InvalidRecipient(address recipient);
    error NullifierAlreadyConsumed(bytes32 nullifier);
    error ProofVerificationFailed();

    /// @notice Claims ETH by submitting a valid ZK proof.
    /// @param _proof The serialized ZK proof.
    /// @param _input The public inputs for verification.
    function claim(bytes calldata _proof, PublicInput calldata _input) external;

    /// @notice Checks if a nullifier has been consumed.
    /// @param _nullifier The nullifier to check.
    /// @return _isConsumed_ True if already used.
    function isConsumed(bytes32 _nullifier) external view returns (bool _isConsumed_);
}
