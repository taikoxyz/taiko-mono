// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibClaimRecordCodec
/// @notice Optimized library for encoding/decoding claim record data with bit-packing
/// @custom:security-contact security@taiko.xyz
library LibClaimRecordCodec {
    uint256 private constant MAX_BOND_INSTRUCTIONS = 127;
    uint256 private constant MAX_BOND_TYPE = 3;

    error INVALID_DATA_LENGTH();
    error BOND_INSTRUCTIONS_ARRAY_EXCEEDS_MAX();
    error BOND_TYPE_EXCEEDS_MAX();

    /// @notice Encodes a ClaimRecord into optimized packed bytes
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data as bytes
    function encode(IInbox.ClaimRecord memory _claimRecord) internal pure returns (bytes memory) {
        // Validate annotated fields
        if (_claimRecord.bondInstructions.length > MAX_BOND_INSTRUCTIONS) {
            revert BOND_INSTRUCTIONS_ARRAY_EXCEEDS_MAX();
        }

        for (uint256 i = 0; i < _claimRecord.bondInstructions.length; i++) {
            if (uint256(_claimRecord.bondInstructions[i].bondType) > MAX_BOND_TYPE) {
                revert BOND_TYPE_EXCEEDS_MAX();
            }
        }

        // Calculate size: 194 bytes base + 47 bytes per bond instruction
        // Layout:
        // - proposalId: 6 bytes
        // - claim.proposalHash: 32 bytes
        // - claim.parentClaimHash: 32 bytes
        // - claim.endBlockNumber: 6 bytes
        // - claim.endBlockHash: 32 bytes
        // - claim.endStateRoot: 32 bytes
        // - claim.designatedProver: 20 bytes
        // - claim.actualProver: 20 bytes
        // - span: 1 byte
        // - bondInstructions.length: 1 byte
        // Total base: 182 bytes

        uint256 bondCount = _claimRecord.bondInstructions.length;
        uint256 size = 182 + (bondCount * 47);
        bytes memory result = new bytes(size);

        assembly {
            let ptr := add(result, 0x20)
            let cr := _claimRecord

            // Pack proposalId (6 bytes)
            let proposalId := mload(cr)
            mstore8(ptr, shr(40, proposalId))
            mstore8(add(ptr, 1), shr(32, proposalId))
            mstore8(add(ptr, 2), shr(24, proposalId))
            mstore8(add(ptr, 3), shr(16, proposalId))
            mstore8(add(ptr, 4), shr(8, proposalId))
            mstore8(add(ptr, 5), proposalId)

            // Get claim struct pointer
            let claim := mload(add(cr, 0x20))

            // Copy proposalHash (32 bytes)
            mstore(add(ptr, 6), mload(claim))

            // Copy parentClaimHash (32 bytes)
            mstore(add(ptr, 38), mload(add(claim, 0x20)))

            // Pack endBlockNumber (6 bytes)
            let endBlockNumber := mload(add(claim, 0x40))
            mstore8(add(ptr, 70), shr(40, endBlockNumber))
            mstore8(add(ptr, 71), shr(32, endBlockNumber))
            mstore8(add(ptr, 72), shr(24, endBlockNumber))
            mstore8(add(ptr, 73), shr(16, endBlockNumber))
            mstore8(add(ptr, 74), shr(8, endBlockNumber))
            mstore8(add(ptr, 75), endBlockNumber)

            // Copy endBlockHash (32 bytes)
            mstore(add(ptr, 76), mload(add(claim, 0x60)))

            // Copy endStateRoot (32 bytes)
            mstore(add(ptr, 108), mload(add(claim, 0x80)))

            // Pack designatedProver (20 bytes)
            let designatedProver := mload(add(claim, 0xa0))
            mstore(add(ptr, 140), shl(96, designatedProver))

            // Pack actualProver (20 bytes)
            let actualProver := mload(add(claim, 0xc0))
            mstore(add(ptr, 160), shl(96, actualProver))

            // Pack span (1 byte)
            mstore8(add(ptr, 180), mload(add(cr, 0x40)))

            // Pack bondInstructions length (1 byte)
            mstore8(add(ptr, 181), bondCount)

            // Pack bond instructions
            ptr := add(ptr, 182)
            let bondArray := mload(add(cr, 0x60))
            let bondData := add(bondArray, 0x20)

            for { let i := 0 } lt(i, bondCount) { i := add(i, 1) } {
                let bond := mload(add(bondData, mul(i, 0x20)))

                // Pack proposalId (6 bytes)
                let bProposalId := mload(bond)
                mstore8(ptr, shr(40, bProposalId))
                mstore8(add(ptr, 1), shr(32, bProposalId))
                mstore8(add(ptr, 2), shr(24, bProposalId))
                mstore8(add(ptr, 3), shr(16, bProposalId))
                mstore8(add(ptr, 4), shr(8, bProposalId))
                mstore8(add(ptr, 5), bProposalId)

                // Pack bondType (1 byte)
                mstore8(add(ptr, 6), mload(add(bond, 0x20)))

                // Pack payer (20 bytes)
                mstore(add(ptr, 7), shl(96, mload(add(bond, 0x40))))

                // Pack receiver (20 bytes)
                mstore(add(ptr, 27), shl(96, mload(add(bond, 0x60))))

                ptr := add(ptr, 47)
            }
        }

        return result;
    }

    /// @notice Decodes packed bytes into a ClaimRecord
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        if (_data.length < 182) revert INVALID_DATA_LENGTH();

        assembly {
            let ptr := add(_data, 0x20)

            // Decode proposalId (6 bytes)
            let proposalId := 0
            proposalId := or(proposalId, shl(40, mload8(ptr)))
            proposalId := or(proposalId, shl(32, mload8(add(ptr, 1))))
            proposalId := or(proposalId, shl(24, mload8(add(ptr, 2))))
            proposalId := or(proposalId, shl(16, mload8(add(ptr, 3))))
            proposalId := or(proposalId, shl(8, mload8(add(ptr, 4))))
            proposalId := or(proposalId, mload8(add(ptr, 5)))
            mstore(claimRecord_, proposalId)

            // Allocate claim struct
            let claim := mload(0x40)
            mstore(0x40, add(claim, 0xe0))
            mstore(add(claimRecord_, 0x20), claim)

            // Decode proposalHash (32 bytes)
            mstore(claim, mload(add(ptr, 6)))

            // Decode parentClaimHash (32 bytes)
            mstore(add(claim, 0x20), mload(add(ptr, 38)))

            // Decode endBlockNumber (6 bytes)
            let endBlockNumber := 0
            endBlockNumber := or(endBlockNumber, shl(40, mload8(add(ptr, 70))))
            endBlockNumber := or(endBlockNumber, shl(32, mload8(add(ptr, 71))))
            endBlockNumber := or(endBlockNumber, shl(24, mload8(add(ptr, 72))))
            endBlockNumber := or(endBlockNumber, shl(16, mload8(add(ptr, 73))))
            endBlockNumber := or(endBlockNumber, shl(8, mload8(add(ptr, 74))))
            endBlockNumber := or(endBlockNumber, mload8(add(ptr, 75)))
            mstore(add(claim, 0x40), endBlockNumber)

            // Decode endBlockHash (32 bytes)
            mstore(add(claim, 0x60), mload(add(ptr, 76)))

            // Decode endStateRoot (32 bytes)
            mstore(add(claim, 0x80), mload(add(ptr, 108)))

            // Decode designatedProver (20 bytes)
            mstore(add(claim, 0xa0), shr(96, mload(add(ptr, 140))))

            // Decode actualProver (20 bytes)
            mstore(add(claim, 0xc0), shr(96, mload(add(ptr, 160))))

            // Decode span (1 byte)
            mstore(add(claimRecord_, 0x40), mload8(add(ptr, 180)))

            // Decode bondInstructions length (1 byte)
            let bondCount := mload8(add(ptr, 181))

            // Allocate bond instructions array
            let bondArray := mload(0x40)
            mstore(bondArray, bondCount)
            mstore(0x40, add(bondArray, mul(add(bondCount, 1), 0x20)))
            mstore(add(claimRecord_, 0x60), bondArray)

            // Decode bond instructions
            ptr := add(ptr, 182)
            let bondArrayData := add(bondArray, 0x20)

            for { let i := 0 } lt(i, bondCount) { i := add(i, 1) } {
                // Allocate bond struct
                let bond := mload(0x40)
                mstore(0x40, add(bond, 0x80))

                // Decode proposalId (6 bytes)
                let bProposalId := 0
                bProposalId := or(bProposalId, shl(40, mload8(ptr)))
                bProposalId := or(bProposalId, shl(32, mload8(add(ptr, 1))))
                bProposalId := or(bProposalId, shl(24, mload8(add(ptr, 2))))
                bProposalId := or(bProposalId, shl(16, mload8(add(ptr, 3))))
                bProposalId := or(bProposalId, shl(8, mload8(add(ptr, 4))))
                bProposalId := or(bProposalId, mload8(add(ptr, 5)))
                mstore(bond, bProposalId)

                // Decode bondType (1 byte)
                mstore(add(bond, 0x20), mload8(add(ptr, 6)))

                // Decode payer (20 bytes)
                mstore(add(bond, 0x40), shr(96, mload(add(ptr, 7))))

                // Decode receiver (20 bytes)
                mstore(add(bond, 0x60), shr(96, mload(add(ptr, 27))))

                // Store bond in array
                mstore(add(bondArrayData, mul(i, 0x20)), bond)

                ptr := add(ptr, 47)
            }

            // Helper function for mload8
            function mload8(addr) -> result {
                result := and(mload(addr), 0xff)
            }
        }
    }
}
