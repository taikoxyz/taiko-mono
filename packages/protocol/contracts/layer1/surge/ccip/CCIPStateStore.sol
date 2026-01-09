// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AzureTDXVerifier } from "./AzureTDXVerifier.sol";
import { ICCIPStateStore } from "./ICCIPStateStore.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

/// @title CCIPStateStore
/// @notice Contract for syncing and storing L2 chain state for CCIP integration.
/// Uses TDX attestation for verifying state proofs from trusted instances.
/// @custom:security-contact security@nethermind.io
contract CCIPStateStore is AzureTDXVerifier, ICCIPStateStore {
    /// @notice Minimum delay (in seconds) required between state syncs
    uint256 public constant MIN_SYNC_DELAY = 384;

    /// @dev The latest synced state
    /// 3 Slots
    SyncedState private _syncedState;

    uint256[47] private __gap;

    /// @notice Emitted when L2 state is synced
    /// @param blockHash The hash of the synced block
    /// @param stateRoot The state root of the synced block
    /// @param syncedAt The timestamp when the state was synced
    event StateSynced(bytes32 indexed blockHash, bytes32 indexed stateRoot, uint256 syncedAt);

    constructor(address _automataDcapAttestation) AzureTDXVerifier(_automataDcapAttestation) { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICCIPStateStore
    function syncState(bytes calldata _proof) external {
        require(
            block.timestamp > _syncedState.syncedAt + MIN_SYNC_DELAY, SurgeCCIP_SyncTooFrequent()
        );

        // Decode proof: blockhash (32 bytes) || stateroot (32 bytes) || signature (65 bytes)
        require(_proof.length == 129, SurgeCCIP_InvalidProofLength());

        bytes32 blockHash = bytes32(_proof[:32]);
        bytes32 stateRoot = bytes32(_proof[32:64]);
        bytes memory signature = _proof[64:];

        // Recover signer from signature over (blockhash || stateroot) and verify it's a registered instance
        bytes32 message = EfficientHashLib.hash(blockHash, stateRoot);
        address signer = ECDSA.recover(message, signature);
        require(instances[signer], SurgeCCIP_InvalidSigner());

        // Update synced state
        _syncedState =
            SyncedState({ syncedAt: block.timestamp, stateRoot: stateRoot, blockHash: blockHash });

        emit StateSynced(blockHash, stateRoot, block.timestamp);
    }

    /// @inheritdoc ICCIPStateStore
    function getSyncedState() external view returns (SyncedState memory) {
        return _syncedState;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error SurgeCCIP_SyncTooFrequent();
    error SurgeCCIP_InvalidProofLength();
    error SurgeCCIP_InvalidSigner();
}

