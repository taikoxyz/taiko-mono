// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ISignalService } from "./ISignalService.sol";

/// @title ISignalServiceL2
/// @notice L2 signal verification using timestamp-indexed L1 execution state roots.
/// @dev The Etna proof encoding is the four-byte STATE_ROOT_PROOF_MAGIC prefix followed by
/// abi.encode(StateRootProof). Existing HopProof[] and empty cached proofs retain their encoding.
/// @custom:security-contact security@taiko.xyz
interface ISignalServiceL2 is ISignalService {
    /// @notice Merkle proof against the L1 state root recorded at an Etna L2 timestamp.
    struct StateRootProof {
        /// @notice L2 oracle timestamp, not an L1 block number or timestamp.
        uint64 l2Timestamp;
        /// @notice Account proof for the configured remote SignalService.
        bytes[] accountProof;
        /// @notice Storage proof for the signal slot under that account.
        bytes[] storageProof;
    }
}
