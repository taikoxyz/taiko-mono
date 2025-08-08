// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IStorage
/// @notice Interface for the Taiko Alethia protocol storage
/// @dev Defines the storage struct and layout of the Taiko Alethia protocol
/// @custom:security-contact security@taiko.xyz
interface IStorage {
    /// @notice Struct representing transition storage
    /// @dev Uses 2 storage slots per transition for gas efficiency
    struct TransitionState {
        /// @notice Packed batch ID and partial parent hash for storage efficiency
        uint256 batchIdAndPartialParentHash;
        /// @notice Hash of the transition metadata
        bytes32 metaHash;
    }

    /// @notice State variables for the Taiko protocol contract
    /// @dev Contains all persistent state including mappings and storage gaps for upgrades
    struct State {
        /// @notice Ring buffer for proposed and verified batch metadata hashes
        mapping(uint256 batchId_mod_batchRingBufferSize => bytes32 metaHash) batches;
        /// @notice Mapping from batch ID and parent hash to transition metadata hash
        mapping(uint256 batchId => mapping(bytes32 parentHash => bytes32 metahash))
            transitionMetaHashes;
        /// @notice Ring buffer for transition states
        mapping(
            uint256 batchId_mod_batchRingBufferSize
                => mapping(uint256 thisValueIsAlways1 => TransitionState ts)
        ) transitions;
        /// @notice Hash of the current protocol summary (storage slot 4)
        bytes32 summaryHash;
        /// @notice Deprecated statistics field (storage slot 5)
        bytes32 __deprecatedStats1;
        /// @notice Deprecated statistics field (storage slot 6)
        bytes32 __deprecatedStats2;
        /// @notice Mapping of account addresses to their bond balances
        mapping(address account => uint256 bond) bondBalance;
        /// @notice Storage gap for future upgrades
        uint256[43] __gap;
    }
}
