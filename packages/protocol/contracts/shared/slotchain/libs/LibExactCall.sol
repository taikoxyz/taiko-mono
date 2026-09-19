// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain exact bounded external calls
/// @custom:security-contact security@taiko.xyz
library LibExactCall {
    /// @dev Covers a warm CALL/STATICCALL instruction and the fixed return envelope. The exact
    ///      return-copy charge is added separately by `minimumCallerGas`.
    uint256 internal constant CALL_ENVELOPE_GAS = 10_000;

    /// @dev Performs a runtime-authenticated, zero-value STATICCALL with exact input, gas and
    ///      returndata length. Revert and unexpected-size returndata are never copied.
    /// @param _target The nonempty immutable target account.
    /// @param _expectedRuntimeHash The release-pinned target runtime hash.
    /// @param _input The complete calldata; the helper appends no bytes.
    /// @param _gasLimit The exact gas operand requested by STATICCALL.
    /// @param _returnLength The sole accepted returndata length.
    /// @param _postCopyReserve The minimum gas that must remain after exact return-data copy.
    /// @return output_ The exact target returndata.
    function staticcallExact(
        address _target,
        bytes32 _expectedRuntimeHash,
        bytes memory _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        internal
        view
        returns (bytes memory output_)
    {
        output_ = _allocateAndTouch(_returnLength);
        requireRuntime(_target, _expectedRuntimeHash);
        _requireCallerGas(_gasLimit, _returnLength, _postCopyReserve);

        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := staticcall(_gasLimit, _target, add(_input, 32), mload(_input), 0, 0)
            actualLength := returndatasize()
        }
        if (!success) revert ExactCallFailed(_target, _selector(_input));
        if (actualLength != _returnLength) {
            revert ExactReturnLengthMismatch(_target, actualLength, _returnLength);
        }
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
        if (gasleft() < _postCopyReserve) revert ExactPostCopyGasTooLow();
    }

    /// @dev Performs a runtime-authenticated CALL with exact input, value, gas and returndata
    ///      length. Revert and unexpected-size returndata are never copied.
    /// @param _target The nonempty immutable target account.
    /// @param _expectedRuntimeHash The release-pinned target runtime hash.
    /// @param _value The exact native value sent to the target.
    /// @param _input The complete calldata; the helper appends no bytes.
    /// @param _gasLimit The exact gas operand requested by CALL.
    /// @param _returnLength The sole accepted returndata length.
    /// @param _postCopyReserve The minimum gas that must remain after exact return-data copy.
    /// @return output_ The exact target returndata.
    function callExact(
        address _target,
        bytes32 _expectedRuntimeHash,
        uint256 _value,
        bytes memory _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        internal
        returns (bytes memory output_)
    {
        output_ = _allocateAndTouch(_returnLength);
        requireRuntime(_target, _expectedRuntimeHash);
        _requireCallerGas(_gasLimit, _returnLength, _postCopyReserve);

        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := call(_gasLimit, _target, _value, add(_input, 32), mload(_input), 0, 0)
            actualLength := returndatasize()
        }
        if (!success) revert ExactCallFailed(_target, _selector(_input));
        if (actualLength != _returnLength) {
            revert ExactReturnLengthMismatch(_target, actualLength, _returnLength);
        }
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
        if (gasleft() < _postCopyReserve) revert ExactPostCopyGasTooLow();
    }

    /// @dev Authenticates a nonempty runtime and its exact selector-only bytes32 configuration
    ///      getter. A zero expected configuration is never a valid release identity.
    function requireConfiguration(
        address _target,
        bytes32 _expectedRuntimeHash,
        bytes4 _configurationSelector,
        bytes32 _expectedConfigurationHash,
        uint256 _gasLimit,
        uint256 _postCopyReserve
    )
        internal
        view
    {
        if (_configurationSelector == bytes4(0) || _expectedConfigurationHash == bytes32(0)) {
            revert ExactConfigurationMismatch(_target);
        }
        bytes memory output = staticcallExact(
            _target,
            _expectedRuntimeHash,
            abi.encodePacked(_configurationSelector),
            _gasLimit,
            32,
            _postCopyReserve
        );
        if (word(output, 0) != _expectedConfigurationHash) {
            revert ExactConfigurationMismatch(_target);
        }
    }

    /// @dev Rejects zero/empty accounts and requires the exact release-pinned runtime hash.
    function requireRuntime(address _target, bytes32 _expectedRuntimeHash) internal view {
        bytes32 actualRuntimeHash;
        uint256 codeSize;
        assembly ("memory-safe") {
            actualRuntimeHash := extcodehash(_target)
            codeSize := extcodesize(_target)
        }
        if (
            _target == address(0) || codeSize == 0 || _expectedRuntimeHash == bytes32(0)
                || actualRuntimeHash != _expectedRuntimeHash
        ) {
            revert ExactRuntimeMismatch(_target, _expectedRuntimeHash, actualRuntimeHash);
        }
    }

    /// @dev Returns the conservative caller gas required after output-memory preparation and a
    ///      warm runtime check: full EIP-150 forwarding, fixed call envelope, exact copy and the
    ///      requested post-copy reserve. The EIP-150 headroom and post-copy reserve are concurrent
    ///      lower bounds on the gas retained outside the callee, so their maximum--not their
    ///      sum--is required.
    function minimumCallerGas(
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        internal
        pure
        returns (uint256 minimum_)
    {
        uint256 eip150Headroom = _gasLimit / 63 + (_gasLimit % 63 == 0 ? 0 : 1);
        uint256 returnWords = _returnLength / 32 + (_returnLength % 32 == 0 ? 0 : 1);
        uint256 envelope = CALL_ENVELOPE_GAS + 3 + 3 * returnWords;
        uint256 retainedGas = eip150Headroom > _postCopyReserve ? eip150Headroom : _postCopyReserve;
        if (
            _gasLimit > type(uint256).max - retainedGas
                || _gasLimit + retainedGas > type(uint256).max - envelope
        ) {
            revert ExactGasCalculationOverflow();
        }
        return _gasLimit + retainedGas + envelope;
    }

    /// @dev Loads one complete word from exact returndata.
    function word(bytes memory _raw, uint256 _index) internal pure returns (bytes32 value_) {
        if (_index >= _raw.length / 32 || _raw.length % 32 != 0) {
            revert ExactMalformedReturnWord(_index);
        }
        assembly ("memory-safe") {
            value_ := mload(add(add(_raw, 32), mul(_index, 32)))
        }
    }

    /// @dev Decodes one canonical ABI address word. Zero is canonical; callers decide whether it
    ///      is semantically permitted.
    function addressWord(
        bytes memory _raw,
        uint256 _index
    )
        internal
        pure
        returns (address value_)
    {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint160).max) revert ExactMalformedReturnWord(_index);
        return address(uint160(value));
    }

    /// @dev Decodes one canonical ABI bytes4 word with right-zero padding.
    function bytes4Word(
        bytes memory _raw,
        uint256 _index
    )
        internal
        pure
        returns (bytes4 value_)
    {
        bytes32 value = word(_raw, _index);
        if (uint224(uint256(value)) != 0) revert ExactMalformedReturnWord(_index);
        return bytes4(value);
    }

    /// @dev Decodes one canonical ABI boolean word.
    function boolWord(bytes memory _raw, uint256 _index) internal pure returns (bool value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > 1) revert ExactMalformedReturnWord(_index);
        return value == 1;
    }

    /// @dev Decodes one canonical ABI uint8 word.
    function u8Word(bytes memory _raw, uint256 _index) internal pure returns (uint8 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint8).max) revert ExactMalformedReturnWord(_index);
        return uint8(value);
    }

    /// @dev Decodes one canonical ABI uint16 word.
    function u16Word(bytes memory _raw, uint256 _index) internal pure returns (uint16 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint16).max) revert ExactMalformedReturnWord(_index);
        return uint16(value);
    }

    /// @dev Decodes one canonical ABI uint32 word.
    function u32Word(bytes memory _raw, uint256 _index) internal pure returns (uint32 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint32).max) revert ExactMalformedReturnWord(_index);
        return uint32(value);
    }

    /// @dev Decodes one canonical ABI uint64 word.
    function u64Word(bytes memory _raw, uint256 _index) internal pure returns (uint64 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint64).max) revert ExactMalformedReturnWord(_index);
        return uint64(value);
    }

    /// @dev Decodes one canonical ABI uint192 word.
    function u192Word(
        bytes memory _raw,
        uint256 _index
    )
        internal
        pure
        returns (uint192 value_)
    {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint192).max) revert ExactMalformedReturnWord(_index);
        return uint192(value);
    }

    /// @dev Allocates and touches the exact output region before the gas preflight.
    function _allocateAndTouch(uint256 _returnLength) private pure returns (bytes memory output_) {
        output_ = new bytes(_returnLength);
        if (_returnLength != 0) {
            assembly ("memory-safe") {
                mstore8(add(add(output_, 31), _returnLength), 0)
            }
        }
    }

    /// @dev Enforces the full EIP-150 and post-copy reserve relation.
    function _requireCallerGas(
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        private
        view
    {
        if (gasleft() < minimumCallerGas(_gasLimit, _returnLength, _postCopyReserve)) {
            revert ExactInsufficientCallGas();
        }
    }

    /// @dev Returns the first four input bytes, right-zero-padded for short inputs.
    function _selector(bytes memory _input) private pure returns (bytes4 selector_) {
        if (_input.length == 0) return bytes4(0);
        assembly ("memory-safe") {
            selector_ := mload(add(_input, 32))
        }
    }

    error ExactCallFailed(address target, bytes4 selector);
    error ExactConfigurationMismatch(address target);
    error ExactGasCalculationOverflow();
    error ExactInsufficientCallGas();
    error ExactMalformedReturnWord(uint256 index);
    error ExactPostCopyGasTooLow();
    error ExactReturnLengthMismatch(address target, uint256 actual, uint256 expected);
    error ExactRuntimeMismatch(address target, bytes32 expected, bytes32 actual);
}
