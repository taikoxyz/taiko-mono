// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain destination-registration MPT verifier
/// @custom:security-contact security@taiko.xyz
interface IRegistrationMptVerifierV2 {
    /// @notice Exact authenticated destination-registration statement.
    /// @dev Every field is derived by the calling registry; proof bytes carry no statement field.
    struct RegistrationStorageStatementV2 {
        /// @notice Settlement-chain ID whose router supplied the canonical state root.
        uint256 settlementChainId;
        /// @notice Protocol-lifetime ActiveSettlementRouter on the settlement chain.
        address activeSettlementRouter;
        /// @notice Bridge-domain registry requesting verification.
        address bridgeDomainRegistry;
        /// @notice Exact source-to-destination route key.
        bytes32 routeKey;
        /// @notice Destination chain ID authenticated by the registration commitment.
        uint256 destinationChainId;
        /// @notice Protocol release version whose destination registration is proven.
        uint64 protocolVersion;
        /// @notice Exact canonical-history sequence that supplied `stateRoot`.
        uint64 canonicalSequence;
        /// @notice Authenticated destination execution-state root.
        bytes32 stateRoot;
        /// @notice Terminal-domain registrar account proven under `stateRoot`.
        address terminalDomainRegistrar;
        /// @notice Pinned runtime code hash required for the registrar account.
        bytes32 registrarCodeHash;
        /// @notice Exact hashed storage-trie key of the versioned registration commitment.
        bytes32 storageTrieKey;
        /// @notice Exact nonzero registration-commitment storage word.
        bytes32 expectedValue;
    }

    /// @notice Returns the immutable verifier configuration commitment.
    /// @return configHash_ The frozen `RegistrationMptVerifierConfigV2` hash.
    function registrationMptVerifierConfigHashV2() external view returns (bytes32 configHash_);

    /// @notice Verifies one registrar-account and registration-storage membership proof.
    /// @dev Calldata and the packed proof must use their sole canonical encodings. Absence proofs
    ///      are rejected. Success returns the exact EIP-712-style statement hash, not a Boolean.
    /// @param _statement The complete caller-derived registration statement.
    /// @param _proof The bounded canonical `MptProofV1` container.
    /// @return statementHash_ The hash of the exact verified statement.
    function verifyRegistration(
        RegistrationStorageStatementV2 calldata _statement,
        bytes calldata _proof
    )
        external
        view
        returns (bytes32 statementHash_);
}
