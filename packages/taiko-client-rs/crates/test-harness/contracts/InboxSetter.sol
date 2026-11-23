// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Test-only Inbox storage setter.
/// @dev Installed by the test harness; never deploy this unrestricted setter in production.
contract InboxSetter {
    /// @notice One entry of the Inbox's fallback key list: the prefix byte and X coordinate of a
    /// compressed secp256k1 public key.
    struct FallbackKey {
        uint8 ckPrefix;
        bytes32 ckX;
    }

    /// @dev `bytes32("ETNA_FALLBACK_KEYS_V1")`, the domain tag of a fallback key list's hash.
    bytes32 private constant FALLBACK_KEYS_TAG = "ETNA_FALLBACK_KEYS_V1";

    /// @dev Every planted fallback key list by its hash. A mapping writes no word at its own slot,
    /// so the lists stay apart from every Inbox slot.
    mapping(bytes32 fallbackKeysHash => FallbackKey[] keys) private plantedFallbackKeys;

    event ForcedInclusionSaved(uint48 indexed index, bytes tx, uint256 feeWei);
    event FallbackKeysUpdated(bytes32 indexed fallbackKeysHash, FallbackKey[] keys);

    /// @notice Plants a forced transaction and emits its protocol admission event.
    /// @dev Writes the Inbox's `ForcedInclusion` entry: the transaction hash, then the timestamp
    /// (bits 0-47) and block number (bits 48-95) of the transaction that writes the entry. The
    /// entry holds no fee; the fee appears only in the event.
    /// @param _index The queue index to populate.
    /// @param _tx The raw transaction bytes.
    /// @param _feeInGwei The admission fee in gwei, emitted in wei.
    function plantForcedTransaction(uint48 _index, bytes calldata _tx, uint64 _feeInGwei) external {
        bytes32 base = keccak256(abi.encode(_index, uint256(280)));
        bytes32 txHash = keccak256(_tx);
        uint256 packed = uint256(uint48(block.timestamp)) | (uint256(uint48(block.number)) << 48);
        assembly {
            sstore(base, txHash)
            sstore(add(base, 1), packed)
            let prior := sload(281)
            sstore(281, or(and(prior, sub(shl(48, 1), 1)), shl(48, add(_index, 1))))
        }
        emit ForcedInclusionSaved(_index, _tx, uint256(_feeInGwei) * 1 gwei);
    }

    /// @notice Plants a fallback key list as the Inbox's `setFallbackKeys` stores it, unchecked.
    /// @dev Writes the list's hash, `keccak256(abi.encode(FALLBACK_KEYS_TAG, keys))`, at slot 278,
    /// keeps the list for `getFallbackKeys` and emits `FallbackKeysUpdated`. A list planted again
    /// is kept once.
    /// @param _keys The fallback key list.
    function plantFallbackKeys(FallbackKey[] calldata _keys) external {
        bytes32 hash = keccak256(abi.encode(FALLBACK_KEYS_TAG, _keys));
        FallbackKey[] storage planted = plantedFallbackKeys[hash];
        if (planted.length == 0) {
            for (uint256 i; i < _keys.length; ++i) {
                planted.push(_keys[i]);
            }
        }
        assembly {
            sstore(278, hash)
        }
        emit FallbackKeysUpdated(hash, _keys);
    }

    /// @notice Returns the planted fallback key list whose hash slot 278 holds.
    /// @return keys_ The list, empty when no list with that hash was planted.
    function getFallbackKeys() external view returns (FallbackKey[] memory keys_) {
        bytes32 hash;
        assembly {
            hash := sload(278)
        }
        keys_ = plantedFallbackKeys[hash];
    }

    /// @notice Applies raw calldata pairs of storage slots and values.
    /// @dev Preserves the generic Inbox planting interface.
    fallback() external {
        assembly {
            for { let offset := 0 } lt(offset, calldatasize()) { offset := add(offset, 64) } {
                sstore(calldataload(offset), calldataload(add(offset, 32)))
            }
        }
    }
}
