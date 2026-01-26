// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IShadow} from "../iface/IShadow.sol";

/// @custom:security-contact security@taiko.xyz

library ShadowPublicInputs {
    uint256 private constant _PUBLIC_INPUTS_LEN = 120;
    uint256 private constant _IDX_BLOCK_NUMBER = 0;
    uint256 private constant _IDX_STATE_ROOT = 1;
    uint256 private constant _IDX_CHAIN_ID = 33;
    uint256 private constant _IDX_NOTE_INDEX = 34;
    uint256 private constant _IDX_AMOUNT = 35;
    uint256 private constant _IDX_RECIPIENT = 36;
    uint256 private constant _IDX_NULLIFIER = 56;
    uint256 private constant _IDX_POW_DIGEST = 88;
    uint256 private constant _POW_ZERO_BITS = 24;
    uint256 private constant _POW_MASK = (1 << _POW_ZERO_BITS) - 1;

    /// @notice Converts a PublicInput struct to a uint256 array for circuit verification.
    function toArray(IShadow.PublicInput calldata _input) internal pure returns (uint256[] memory inputs_) {
        inputs_ = new uint256[](_PUBLIC_INPUTS_LEN);

        inputs_[_IDX_BLOCK_NUMBER] = _input.blockNumber;

        _writeBytes32(inputs_, _IDX_STATE_ROOT, _input.stateRoot);

        inputs_[_IDX_CHAIN_ID] = _input.chainId;
        inputs_[_IDX_NOTE_INDEX] = _input.noteIndex;
        inputs_[_IDX_AMOUNT] = _input.amount;

        _writeAddress(inputs_, _IDX_RECIPIENT, _input.recipient);
        _writeBytes32(inputs_, _IDX_NULLIFIER, _input.nullifier);
        _writeBytes32(inputs_, _IDX_POW_DIGEST, _input.powDigest);
    }

    /// @notice Returns whether the POW digest has the required number of trailing zero bits.
    function powDigestIsValid(bytes32 _powDigest) internal pure returns (bool) {
        return (uint256(_powDigest) & _POW_MASK) == 0;
    }

    function _writeBytes32(uint256[] memory _inputs, uint256 _offset, bytes32 _value) private pure {
        for (uint256 i = 0; i < 32;) {
            _inputs[_offset + i] = uint256(uint8(_value[i]));
            unchecked {
                ++i;
            }
        }
    }

    function _writeAddress(uint256[] memory _inputs, uint256 _offset, address _value) private pure {
        for (uint256 i = 0; i < 20;) {
            _inputs[_offset + i] = uint256(uint8(bytes20(_value)[i]));
            unchecked {
                ++i;
            }
        }
    }
}
