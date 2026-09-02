// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibCanonicalRLP } from "../../../shared/slotchain/libs/LibCanonicalRLP.sol";

/// @title Exact EIP-4788 and EIP-2935 history authentication
/// @custom:security-contact security@taiko.xyz
library LibHistoryProof {
    address internal constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address internal constant HISTORY_STORAGE_ADDRESS = 0x0000F90827F1C53a10cb7A02335B175320002935;

    uint256 internal constant BEACON_ROOTS_READ_GAS = 50_000;
    uint256 internal constant HISTORY_READ_GAS = 50_000;
    uint256 internal constant BLOCKHASH_SERVE_WINDOW = 256;
    uint256 internal constant HISTORY_SERVE_WINDOW = 8191;
    uint256 internal constant MAX_EXECUTION_HEADER_BYTES = 2048;
    uint256 internal constant MIN_EXECUTION_HEADER_FIELDS = 20;
    uint256 internal constant MAX_EXECUTION_HEADER_FIELDS = 32;

    struct ExecutionHeader {
        bytes32 blockHash;
        bytes32 parentHash;
        bytes32 stateRoot;
        uint64 blockNumber;
        uint64 timestamp;
        bytes32 parentBeaconBlockRoot;
    }

    /// @dev Executes one exact EIP-4788 query. Only call-level revert means that the timestamp is
    ///      absent; successful malformed or zero returndata is fatal.
    /// @param _timestamp The nonzero timestamp encoded as one 32-byte big-endian call word.
    /// @param _expectedRuntimeHash The release-pinned beacon-roots runtime hash.
    /// @return present_ Whether the system contract accepted the timestamp.
    /// @return root_ The nonzero parent beacon-block root when present.
    function tryReadBeaconRoot(
        uint64 _timestamp,
        bytes32 _expectedRuntimeHash
    )
        internal
        view
        returns (bool present_, bytes32 root_)
    {
        if (_timestamp == 0) revert InvalidBeaconRootTimestamp();
        _requireRuntime(BEACON_ROOTS_ADDRESS, _expectedRuntimeHash);
        _requireForwardableGas(BEACON_ROOTS_READ_GAS, BEACON_ROOTS_ADDRESS);

        bool success;
        uint256 returnLength;
        assembly ("memory-safe") {
            mstore(0, _timestamp)
            success := staticcall(BEACON_ROOTS_READ_GAS, BEACON_ROOTS_ADDRESS, 0, 32, 0, 0)
            returnLength := returndatasize()
        }
        if (!success) return (false, bytes32(0));
        if (returnLength != 32) {
            revert SystemReadLengthMismatch(BEACON_ROOTS_ADDRESS, returnLength, 32);
        }
        assembly ("memory-safe") {
            returndatacopy(0, 0, 32)
            root_ := mload(0)
        }
        if (root_ == bytes32(0)) revert InvalidBeaconRootReturn();
        return (true, root_);
    }

    /// @dev Parses one canonical post-Cancun execution header and authenticates its hash through
    ///      EIP-2935 for the exact requested block. This deliberately does not impose Schedule's
    ///      separate carrier-finality policy.
    /// @param _headerRlp The complete canonical RLP execution header.
    /// @param _requestedBlockNumber The exact block number selected by the calling verifier.
    /// @param _expectedTimestamp The contract-selected carrier query timestamp.
    /// @param _expectedParentBeaconBlockRoot The EIP-4788 root for that timestamp.
    /// @param _historyFirstSupportedBlock The release-pinned EIP-2935 activation boundary.
    /// @param _expectedHistoryRuntimeHash The release-pinned EIP-2935 runtime hash.
    /// @return header_ The authenticated header fields used by the carrier join.
    function authenticateExecutionHeader(
        bytes calldata _headerRlp,
        uint64 _requestedBlockNumber,
        uint64 _expectedTimestamp,
        bytes32 _expectedParentBeaconBlockRoot,
        uint64 _historyFirstSupportedBlock,
        bytes32 _expectedHistoryRuntimeHash
    )
        internal
        view
        returns (ExecutionHeader memory header_)
    {
        _requireRuntime(HISTORY_STORAGE_ADDRESS, _expectedHistoryRuntimeHash);
        _requireHistoryRange(_requestedBlockNumber, _historyFirstSupportedBlock);
        if (_expectedTimestamp == 0 || _expectedParentBeaconBlockRoot == bytes32(0)) {
            revert InvalidExecutionHeaderContext();
        }

        header_ = _parseExecutionHeader(_headerRlp);
        if (
            header_.blockNumber != _requestedBlockNumber || header_.timestamp != _expectedTimestamp
                || header_.parentBeaconBlockRoot != _expectedParentBeaconBlockRoot
        ) {
            revert ExecutionHeaderContextMismatch();
        }

        bytes32 historicalHash = _readHistoricalBlockHash(_requestedBlockNumber);
        if (historicalHash == bytes32(0) || historicalHash != header_.blockHash) {
            revert HistoricalBlockHashMismatch(_requestedBlockNumber);
        }
    }

    /// @dev Authenticates a canonical header through the native 256-block BLOCKHASH window.
    /// @param _headerRlp The complete canonical RLP execution header.
    /// @param _requestedBlockNumber The exact recent ancestor block number.
    /// @return header_ The authenticated execution-header fields.
    function authenticateRecentExecutionHeader(
        bytes calldata _headerRlp,
        uint64 _requestedBlockNumber
    )
        internal
        view
        returns (ExecutionHeader memory header_)
    {
        uint256 currentBlock = block.number;
        if (
            _requestedBlockNumber == 0 || _requestedBlockNumber >= currentBlock
                || currentBlock - uint256(_requestedBlockNumber) > BLOCKHASH_SERVE_WINDOW
        ) {
            revert RecentBlockOutsideRange(_requestedBlockNumber, currentBlock);
        }
        bytes32 expectedHash = blockhash(_requestedBlockNumber);
        if (expectedHash == bytes32(0)) revert RecentBlockHashUnavailable(_requestedBlockNumber);
        return _authenticateStoredExecutionHeader(_headerRlp, _requestedBlockNumber, expectedHash);
    }

    /// @dev Authenticates a canonical header against a previously captured immutable block hash.
    /// @param _headerRlp The complete canonical RLP execution header.
    /// @param _requestedBlockNumber The exact block number bound by the stored context.
    /// @param _expectedBlockHash The nonzero previously captured block hash.
    /// @return header_ The authenticated execution-header fields.
    function authenticateStoredExecutionHeader(
        bytes calldata _headerRlp,
        uint64 _requestedBlockNumber,
        bytes32 _expectedBlockHash
    )
        internal
        pure
        returns (ExecutionHeader memory header_)
    {
        return
            _authenticateStoredExecutionHeader(
                _headerRlp, _requestedBlockNumber, _expectedBlockHash
            );
    }

    /// @dev Decodes the exact header fields needed by the history-carrier join. The first 20
    ///      post-Cancun fields must be RLP byte strings. Canonical appended fields are intentionally
    ///      uninterpreted, while a field count outside 20..32 rejects.
    function _parseExecutionHeader(bytes calldata _headerRlp)
        private
        pure
        returns (ExecutionHeader memory header_)
    {
        uint256 length = _headerRlp.length;
        if (length == 0 || length > MAX_EXECUTION_HEADER_BYTES) {
            revert InvalidExecutionHeaderLength(length);
        }

        LibCanonicalRLP.Item memory root = LibCanonicalRLP.decodeSingle(_headerRlp, 0, length);
        if (!root.isList) revert InvalidExecutionHeaderShape();

        uint256 cursor = root.payloadOffset;
        uint256 end = root.payloadOffset + root.payloadLength;
        uint256 field;
        while (cursor < end) {
            if (field == MAX_EXECUTION_HEADER_FIELDS) revert InvalidExecutionHeaderFieldCount();
            LibCanonicalRLP.Item memory item = LibCanonicalRLP.decodeItem(_headerRlp, cursor, end);
            if (field < MIN_EXECUTION_HEADER_FIELDS && item.isList) {
                revert InvalidExecutionHeaderShape();
            }

            if (field == 0) {
                header_.parentHash = LibCanonicalRLP.readBytes32(_headerRlp, item);
            } else if (field == 3) {
                header_.stateRoot = LibCanonicalRLP.readBytes32(_headerRlp, item);
            } else if (field == 8) {
                header_.blockNumber = LibCanonicalRLP.readUint64(_headerRlp, item);
            } else if (field == 11) {
                header_.timestamp = LibCanonicalRLP.readUint64(_headerRlp, item);
            } else if (field == 19) {
                header_.parentBeaconBlockRoot = LibCanonicalRLP.readBytes32(_headerRlp, item);
            }

            cursor = LibCanonicalRLP.next(item);
            unchecked {
                ++field;
            }
        }
        if (cursor != end || field < MIN_EXECUTION_HEADER_FIELDS) {
            revert InvalidExecutionHeaderFieldCount();
        }
        if (
            header_.parentHash == bytes32(0) || header_.stateRoot == bytes32(0)
                || header_.blockNumber == 0 || header_.timestamp == 0
                || header_.parentBeaconBlockRoot == bytes32(0)
        ) {
            revert InvalidExecutionHeaderField();
        }
        header_.blockHash = keccak256(_headerRlp);
    }

    /// @dev Joins one parsed header to an exact externally authenticated block number/hash pair.
    function _authenticateStoredExecutionHeader(
        bytes calldata _headerRlp,
        uint64 _requestedBlockNumber,
        bytes32 _expectedBlockHash
    )
        private
        pure
        returns (ExecutionHeader memory header_)
    {
        if (_requestedBlockNumber == 0 || _expectedBlockHash == bytes32(0)) {
            revert InvalidStoredBlockContext();
        }
        header_ = _parseExecutionHeader(_headerRlp);
        if (header_.blockNumber != _requestedBlockNumber || header_.blockHash != _expectedBlockHash)
        {
            revert StoredBlockHeaderMismatch(_requestedBlockNumber);
        }
    }

    /// @dev Reads one exact nonzero EIP-2935 hash for a caller-validated block number.
    function _readHistoricalBlockHash(uint64 _blockNumber) private view returns (bytes32 hash_) {
        _requireForwardableGas(HISTORY_READ_GAS, HISTORY_STORAGE_ADDRESS);
        bool success;
        uint256 returnLength;
        assembly ("memory-safe") {
            mstore(0, _blockNumber)
            success := staticcall(HISTORY_READ_GAS, HISTORY_STORAGE_ADDRESS, 0, 32, 0, 0)
            returnLength := returndatasize()
        }
        if (!success) revert HistoricalBlockReadFailed(_blockNumber);
        if (returnLength != 32) {
            revert SystemReadLengthMismatch(HISTORY_STORAGE_ADDRESS, returnLength, 32);
        }
        assembly ("memory-safe") {
            returndatacopy(0, 0, 32)
            hash_ := mload(0)
        }
        if (hash_ == bytes32(0)) revert HistoricalBlockHashMismatch(_blockNumber);
    }

    /// @dev Applies the exact EIP-2935 serving interval and the release activation boundary.
    function _requireHistoryRange(
        uint64 _blockNumber,
        uint64 _firstSupportedBlock
    )
        private
        view
    {
        uint256 currentBlock = block.number;
        uint256 oldest =
            currentBlock > HISTORY_SERVE_WINDOW ? currentBlock - HISTORY_SERVE_WINDOW : 0;
        if (oldest < _firstSupportedBlock) oldest = _firstSupportedBlock;
        if (_blockNumber == 0 || uint256(_blockNumber) < oldest || _blockNumber >= currentBlock) {
            revert HistoricalBlockOutsideRange(_blockNumber, oldest, currentBlock);
        }
    }

    /// @dev Requires one fixed system contract's exact release-pinned runtime.
    function _requireRuntime(address _system, bytes32 _expectedRuntimeHash) private view {
        bytes32 actualRuntimeHash;
        assembly ("memory-safe") {
            actualRuntimeHash := extcodehash(_system)
        }
        if (_expectedRuntimeHash == bytes32(0) || actualRuntimeHash != _expectedRuntimeHash) {
            revert SystemRuntimeMismatch(_system);
        }
    }

    /// @dev Ensures EIP-150 can forward the exact system-read stipend.
    function _requireForwardableGas(uint256 _gasLimit, address _system) private view {
        uint256 margin = _gasLimit / 63 + 10_000;
        if (gasleft() < _gasLimit + margin) revert InsufficientSystemReadGas(_system);
    }

    error ExecutionHeaderContextMismatch();
    error HistoricalBlockHashMismatch(uint64 blockNumber);
    error HistoricalBlockOutsideRange(uint64 blockNumber, uint256 oldest, uint256 currentBlock);
    error HistoricalBlockReadFailed(uint64 blockNumber);
    error InsufficientSystemReadGas(address system);
    error InvalidBeaconRootReturn();
    error InvalidBeaconRootTimestamp();
    error InvalidExecutionHeaderContext();
    error InvalidExecutionHeaderField();
    error InvalidExecutionHeaderFieldCount();
    error InvalidExecutionHeaderLength(uint256 length);
    error InvalidExecutionHeaderShape();
    error InvalidStoredBlockContext();
    error RecentBlockHashUnavailable(uint64 blockNumber);
    error RecentBlockOutsideRange(uint64 blockNumber, uint256 currentBlock);
    error StoredBlockHeaderMismatch(uint64 blockNumber);
    error SystemReadLengthMismatch(address system, uint256 actual, uint256 expected);
    error SystemRuntimeMismatch(address system);
}
