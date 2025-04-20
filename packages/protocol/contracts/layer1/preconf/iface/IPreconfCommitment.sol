// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfCommitment
/// @custom:security-contact security@taiko.xyz
interface IPreconfCommitment {
    /// @dev Preconfirmations are contingent upon the Conditions object evaluating to true. If the
    /// conditions evaluate to false, the preconfer is protected from being penalized.
    struct PreconfConditions {
        uint256 someConditions; // TODO
    }

    enum PreconfAnnotation {
        NONE,
        BEGIN_OF_BATCH,
        END_OF_BATCh,
        BEGIN_OF_PRECONF,
        END_OF_PRECONF
    }

    /// @dev The payload for URC Commitment
    struct PreconfCommitment {
        bytes32 domainSeparator;
        uint256 chainId;
        uint256 batchId;
        uint256 blockId;
        bytes32 blockHash;
        PreconfAnnotation annotation;
        PreconfConditions conditions;
    }
}
