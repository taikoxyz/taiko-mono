// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// import "urc/src/IShasher.sol";

/// @title IPreconfCommitment
/// @custom:security-contact security@taiko.xyz
interface IPreconfCommitment {
    /// @dev Preconfirmations are contingent upon the PreconfirmationCondition object evaluating to
    /// true. If the conditions evaluate to false, the preconfer is protected from being penalized.
    struct Conditions {
        uint256 someConditions; // TODO
    }

    enum Annotation {
        NONE,
        BEGIN_OF_BATCH,
        END_OF_BATCh,
        BEGIN_OF_PRECONF,
        END_OF_PRECONF
    }

    /// @dev The payload for URC Commitment
    struct Commitment {
        bytes32 domainSeparator;
        uint256 chainId;
        uint256 batchId;
        bytes32 blockhash;
        Annotation annotation;
        Conditions conditions;
    }
}
