// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Exact bounded calls and ABI words for protocol-root bootstrap
/// @custom:security-contact security@taiko.xyz
library LibRootBootstrapV1 {
    uint256 internal constant COMPONENT_DEPLOYMENT_GAS_GAP = 510_000;
    uint256 internal constant COMPONENT_DEPLOYMENT_POSTCALL_RESERVE = 500_000;

    /// @dev Performs a bounded STATICCALL, validates exact returndata length, then copies it.
    function staticcallExact(
        address _target,
        bytes memory _input,
        uint256 _gasLimit,
        uint256 _returnLength
    )
        internal
        view
        returns (bytes memory output_)
    {
        _requireCallGas(_gasLimit, 0);
        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := staticcall(_gasLimit, _target, add(_input, 32), mload(_input), 0, 0)
            actualLength := returndatasize()
        }
        if (!success) revert BootstrapExternalCallFailed(_target, _selector(_input));
        if (actualLength != _returnLength) {
            revert BootstrapReturnLengthMismatch(_target, actualLength, _returnLength);
        }
        output_ = new bytes(_returnLength);
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
    }

    /// @dev Performs a bounded CALL and validates exact returndata before copying it.
    function callExact(
        address _target,
        bytes memory _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCallReserve
    )
        internal
        returns (bytes memory output_)
    {
        _requireCallGas(_gasLimit, _postCallReserve);
        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := call(_gasLimit, _target, 0, add(_input, 32), mload(_input), 0, 0)
            actualLength := returndatasize()
        }
        if (!success) revert BootstrapExternalCallFailed(_target, _selector(_input));
        if (actualLength != _returnLength) {
            revert BootstrapReturnLengthMismatch(_target, actualLength, _returnLength);
        }
        if (gasleft() < _postCallReserve) revert BootstrapPostCallGasTooLow();
        output_ = new bytes(_returnLength);
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
    }

    /// @dev Calls a warmed CREATE3 proxy with all gas above the frozen 510,000-gas gap.
    ///      Calldata memory must be fully prepared before entry. Returndata is copied only after
    ///      call success, exact size, and the 500,000-gas post-call boundary all pass.
    function callCreate3ProxyExact(
        address _proxy,
        bytes memory _input,
        uint256 _returnLength
    )
        internal
        returns (bytes memory output_)
    {
        uint256 gasGap = COMPONENT_DEPLOYMENT_GAS_GAP;
        bool enoughGas;
        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            let g0 := gas()
            enoughGas := gt(g0, gasGap)
            if enoughGas {
                success := call(sub(g0, gasGap), _proxy, 0, add(_input, 32), mload(_input), 0, 0)
                actualLength := returndatasize()
            }
        }
        if (!enoughGas) revert BootstrapInsufficientCallGas();
        if (!success) revert BootstrapExternalCallFailed(_proxy, _selector(_input));
        if (actualLength != _returnLength) {
            revert BootstrapReturnLengthMismatch(_proxy, actualLength, _returnLength);
        }
        if (gasleft() < COMPONENT_DEPLOYMENT_POSTCALL_RESERVE) {
            revert BootstrapPostCallGasTooLow();
        }
        output_ = new bytes(_returnLength);
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
    }

    /// @dev Exact-reads componentConfigHashV2() and rejects a zero or mismatched commitment.
    function requireConfiguration(
        address _target,
        bytes32 _expected,
        uint256 _gasLimit
    )
        internal
        view
    {
        if (_expected == bytes32(0)) revert BootstrapConfigurationMismatch(_target);
        bytes memory raw = staticcallExact(_target, hex"f6c0f7d2", _gasLimit, 32);
        if (word(raw, 0) != _expected) revert BootstrapConfigurationMismatch(_target);
    }

    /// @dev Rejects zero/empty accounts and requires one exact runtime hash.
    function requireRuntime(address _target, bytes32 _expected) internal view {
        bytes32 actual;
        assembly ("memory-safe") {
            actual := extcodehash(_target)
        }
        if (_target == address(0) || _expected == bytes32(0) || actual != _expected) {
            revert BootstrapRuntimeMismatch(_target);
        }
    }

    /// @dev Loads one word from exact returndata already sized by this library.
    function word(bytes memory _raw, uint256 _index) internal pure returns (bytes32 value_) {
        assembly ("memory-safe") {
            value_ := mload(add(add(_raw, 32), mul(_index, 32)))
        }
    }

    /// @dev Decodes a canonical nonzero ABI address word.
    function addressWord(
        bytes memory _raw,
        uint256 _index
    )
        internal
        pure
        returns (address value_)
    {
        uint256 value = uint256(word(_raw, _index));
        if (value == 0 || value > type(uint160).max) revert BootstrapMalformedWord(_index);
        return address(uint160(value));
    }

    /// @dev Decodes a canonical uint8 ABI word.
    function u8Word(bytes memory _raw, uint256 _index) internal pure returns (uint8 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint8).max) revert BootstrapMalformedWord(_index);
        return uint8(value);
    }

    /// @dev Decodes a canonical uint16 ABI word.
    function u16Word(bytes memory _raw, uint256 _index) internal pure returns (uint16 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint16).max) revert BootstrapMalformedWord(_index);
        return uint16(value);
    }

    /// @dev Decodes a canonical uint64 ABI word.
    function u64Word(bytes memory _raw, uint256 _index) internal pure returns (uint64 value_) {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint64).max) revert BootstrapMalformedWord(_index);
        return uint64(value);
    }

    /// @dev Decodes a canonical uint192 ABI word.
    function u192Word(
        bytes memory _raw,
        uint256 _index
    )
        internal
        pure
        returns (uint192 value_)
    {
        uint256 value = uint256(word(_raw, _index));
        if (value > type(uint192).max) revert BootstrapMalformedWord(_index);
        return uint192(value);
    }

    /// @dev Requires one left-aligned bytes4 ABI word and zero right padding.
    function requireMagic(bytes memory _raw, bytes4 _expected) internal pure {
        if (word(_raw, 0) != bytes32(_expected)) revert BootstrapMagicMismatch(_expected);
    }

    /// @dev Ensures EIP-150 can forward the stipend and retain the named post-call reserve.
    function _requireCallGas(uint256 _gasLimit, uint256 _postCallReserve) private view {
        uint256 eip150Margin = _gasLimit / 63 + 10_000;
        if (gasleft() < _gasLimit + eip150Margin + _postCallReserve) {
            revert BootstrapInsufficientCallGas();
        }
    }

    /// @dev Reads the selector from one canonical in-memory call buffer.
    function _selector(bytes memory _input) private pure returns (bytes4 selector_) {
        if (_input.length < 4) return bytes4(0);
        assembly ("memory-safe") {
            selector_ := mload(add(_input, 32))
        }
    }

    error BootstrapConfigurationMismatch(address target);
    error BootstrapExternalCallFailed(address target, bytes4 selector);
    error BootstrapInsufficientCallGas();
    error BootstrapMagicMismatch(bytes4 expected);
    error BootstrapMalformedWord(uint256 index);
    error BootstrapPostCallGasTooLow();
    error BootstrapReturnLengthMismatch(address target, uint256 actual, uint256 expected);
    error BootstrapRuntimeMismatch(address target);
}
