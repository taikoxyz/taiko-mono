// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ISignalService
/// @notice The SignalService contract serves as a secure cross-chain message
/// passing system. It defines methods for sending and verifying signals with
/// merkle proofs. The trust assumption is that the target chain has secure
/// access to the merkle root (such as Taiko injects it in the anchor
/// transaction). With this, verifying a signal is reduced to simply verifying
/// a merkle proof.
/// @custom:security-contact security@taiko.xyz
interface ISignalService {
    enum CacheOption {
        CACHE_NOTHING,
        CACHE_SIGNAL_ROOT,
        CACHE_STATE_ROOT,
        CACHE_BOTH
    }

    struct HopProof {
        uint64 chainId;
        uint64 blockId;
        bytes32 rootHash;
        CacheOption cacheOption;
        bytes[] accountProof;
        bytes[] storageProof;
    }

    /// @notice Emitted when a remote chain's state root or signal root is
    /// synced locally as a signal.
    /// @param chainId The remote chainId.
    /// @param blockId The chain data's corresponding blockId.
    /// @param kind A value to mark the data type.
    /// @param data The remote data.
    /// @param signal The signal for this chain data.
    event ChainDataSynced(
        uint64 indexed chainId,
        uint64 indexed blockId,
        bytes32 indexed kind,
        bytes32 data,
        bytes32 signal
    );

    /// @notice Emitted when a signal is sent.
    /// @param app The address that initiated the signal.
    /// @param signal The signal (message) that was sent.
    /// @param slot The location in storage where this signal is stored.
    /// @param value The value of the signal.
    event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);

    /// @notice Emitted when an address is authorized or deauthorized.
    /// @param addr The address to be authorized or deauthorized.
    /// @param authrized True if authorized, false otherwise.
    event Authorized(address indexed addr, bool authrized);

    /// @notice Send a signal (message) by setting the storage slot to a value of 1.
    /// @param _signal The signal (message) to send.
    /// @return slot_ The location in storage where this signal is stored.
    function sendSignal(bytes32 _signal) external returns (bytes32 slot_);

    /// @notice Sync a data from a remote chain locally as a signal. The signal is calculated
    /// uniquely from chainId, kind, and data.
    /// @param _chainId The remote chainId.
    /// @param _kind A value to mark the data type.
    /// @param _blockId The chain data's corresponding blockId
    /// @param _chainData The remote data.
    /// @return signal_ The signal for this chain data.
    function syncChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        external
        returns (bytes32 signal_);

    /// @notice Verifies if a signal has been received on the target chain.
    /// @param _chainId The identifier for the source chain from which the
    /// signal originated.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) to send.
    /// @param _proof Merkle proof that the signal was persisted on the
    /// source chain.
    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external;

    /// @notice Verifies if a particular signal has already been sent.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return true if the signal has been sent, otherwise false.
    function isSignalSent(address _app, bytes32 _signal) external view returns (bool);

    /// @notice Checks if a chain data has been synced.
    /// uniquely from chainId, kind, and data.
    /// @param _chainId The remote chainId.
    /// @param _kind A value to mark the data type.
    /// @param _blockId The chain data's corresponding blockId
    /// @param _chainData The remote data.
    /// @return true if the data has been synced, otherwise false.
    function isChainDataSynced(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        external
        view
        returns (bool);

    /// @notice Returns the given block's  chain data.
    /// @param _chainId Indenitifer of the chainId.
    /// @param _kind A value to mark the data type.
    /// @param _blockId The chain data's corresponding block id. If this value is 0, use the top
    /// block id.
    /// @return blockId_ The actual block id.
    /// @return chainData_ The synced chain data.
    function getSyncedChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId
    )
        external
        view
        returns (uint64 blockId_, bytes32 chainData_);

    /// @notice Returns the data to be used for caching slot generation.
    /// @param _chainId Indenitifer of the chainId.
    /// @param _kind A value to mark the data type.
    /// @param _blockId The chain data's corresponding block id. If this value is 0, use the top
    /// block id.
    /// @return signal_ The signal used for caching slot creation.
    function signalForChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId
    )
        external
        pure
        returns (bytes32 signal_);
}
