// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Test-only Inbox and staking-registry storage setter.
/// @dev Installed by the test harness; never deploy this unrestricted setter in production.
contract InboxSetter {
    event ForcedInclusionSaved(uint48 indexed index, bytes tx, uint256 feeWei);

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

    /// @notice Applies raw calldata pairs of storage slots and values.
    /// @dev Preserves the generic Inbox and staking-registry planting interface.
    fallback() external {
        assembly {
            for { let offset := 0 } lt(offset, calldatasize()) { offset := add(offset, 64) } {
                sstore(calldataload(offset), calldataload(add(offset, 32)))
            }
        }
    }
}
