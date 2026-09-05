// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibRootBootstrapV1
} from "../../../../contracts/layer1/slotchain/root/libs/LibRootBootstrapV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract ExactReturndataTarget {
    fallback() external {
        assembly ("memory-safe") {
            let returnLength := calldataload(4)
            let gasFloor := calldataload(36)
            for { } gt(gas(), gasFloor) { } { }
            return(0, returnLength)
        }
    }
}

contract StatefulOogTarget {
    uint256 public calls;

    fallback() external {
        calls = 1;
        assembly ("memory-safe") {
            for { } 1 { } { }
        }
    }
}

contract LibRootBootstrapV1Harness {
    function requireRuntime(address _target, bytes32 _runtimeHash) external view {
        LibRootBootstrapV1.requireRuntime(_target, _runtimeHash);
    }

    function word(bytes calldata _raw, uint256 _index) external pure returns (bytes32 word_) {
        return LibRootBootstrapV1.word(_raw, _index);
    }

    function callExactNoReturn(
        address _target,
        bytes calldata _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCallReserve
    )
        external
    {
        LibRootBootstrapV1.callExact(_target, _input, _gasLimit, _returnLength, _postCallReserve);
    }

    function callExactGasAfter(
        address _target,
        bytes calldata _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCallReserve
    )
        external
        returns (uint256 gasAfter_, bytes32 outputHash_)
    {
        bytes memory output = LibRootBootstrapV1.callExact(
            _target, _input, _gasLimit, _returnLength, _postCallReserve
        );
        gasAfter_ = gasleft();
        outputHash_ = keccak256(output);
    }

    function callCreate3ProxyExactGasAfter(
        address _target,
        bytes calldata _input,
        uint256 _returnLength
    )
        external
        returns (uint256 gasAfter_, bytes32 outputHash_)
    {
        // callCreate3ProxyExact requires the proxy account to be warm before entry.
        _target.code.length;
        bytes memory output =
            LibRootBootstrapV1.callCreate3ProxyExact(_target, _input, _returnLength);
        gasAfter_ = gasleft();
        outputHash_ = keccak256(output);
    }

    function callCreate3ProxyExactNoReturn(
        address _target,
        bytes calldata _input,
        uint256 _returnLength
    )
        external
    {
        _target.code.length;
        LibRootBootstrapV1.callCreate3ProxyExact(_target, _input, _returnLength);
    }
}

contract LibRootBootstrapV1Test is Test {
    uint256 private constant _LARGE_EXACT_RETURN = 196_608;

    ExactReturndataTarget private _target;
    LibRootBootstrapV1Harness private _harness;

    function setUp() public {
        _target = new ExactReturndataTarget();
        _harness = new LibRootBootstrapV1Harness();
    }

    function test_callExact_LargeReturnPreflightThresholdAndThresholdMinusOne() external {
        uint256 reserve = 250_000;
        bytes memory input = _returnInput(_LARGE_EXACT_RETURN, type(uint256).max);
        bytes memory callData = abi.encodeCall(
            LibRootBootstrapV1Harness.callExactGasAfter,
            (address(_target), input, 500_000, _LARGE_EXACT_RETURN, reserve)
        );
        uint256 threshold = _minimumSuccessfulGas(callData, 750_000, 1_200_000);

        (bool success, bytes memory returndata) = address(_harness).call{ gas: threshold }(callData);
        assertTrue(success);
        (uint256 gasAfter,) = abi.decode(returndata, (uint256, bytes32));
        assertGe(gasAfter, reserve);

        (success, returndata) = address(_harness).call{ gas: threshold - 1 }(callData);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), LibRootBootstrapV1.BootstrapInsufficientCallGas.selector);
    }

    function test_callExact_PreservesReserveAfterLargeExactReturndataCopy() external {
        uint256 reserve = 250_000;
        (uint256 gasAfter, bytes32 outputHash) = _harness.callExactGasAfter{
            gas: 1_200_000
        }(
            address(_target),
            _returnInput(_LARGE_EXACT_RETURN, 350_000),
            500_000,
            _LARGE_EXACT_RETURN,
            reserve
        );

        assertGe(gasAfter, reserve);
        assertTrue(outputHash != bytes32(0));
    }

    function test_callExact_RevertWithoutCopyWhen_ReturndataIsUnexpectedlyHuge() external {
        uint256 unexpectedLength = 1_048_576;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapReturnLengthMismatch.selector,
                address(_target),
                unexpectedLength,
                32
            )
        );
        _harness.callExactNoReturn(
            address(_target), _returnInput(unexpectedLength, type(uint256).max), 3_000_000, 32, 0
        );
    }

    function test_word_RevertWhen_RowIsMisalignedOrIndexIsOutOfBounds() external {
        vm.expectRevert(
            abi.encodeWithSelector(LibRootBootstrapV1.BootstrapMalformedWord.selector, 0)
        );
        _harness.word(hex"00", 0);

        vm.expectRevert(
            abi.encodeWithSelector(LibRootBootstrapV1.BootstrapMalformedWord.selector, 1)
        );
        _harness.word(bytes.concat(bytes32(uint256(1))), 1);
    }

    function test_requireRuntime_RevertWhen_EmptyAccountMatchesEmptyCodeHash() external {
        address empty = address(0xBEEF);
        assertEq(empty.code.length, 0);
        vm.expectRevert(
            abi.encodeWithSelector(LibRootBootstrapV1.BootstrapRuntimeMismatch.selector, empty)
        );
        _harness.requireRuntime(empty, keccak256(bytes("")));
    }

    function test_callExact_CalleeOogRollsBackTargetState() external {
        StatefulOogTarget target = new StatefulOogTarget();
        bytes memory input = hex"deadbeef";
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapExternalCallFailed.selector,
                address(target),
                bytes4(input)
            )
        );
        _harness.callExactNoReturn(address(target), input, 100_000, 0, 0);
        assertEq(target.calls(), 0);
    }

    function test_callExact_ExternalGasThresholdAndThresholdMinusOne() external {
        bytes memory callData = abi.encodeCall(
            LibRootBootstrapV1Harness.callExactNoReturn,
            (address(_target), _returnInput(0, type(uint256).max), 50_000, 0, 50_000)
        );
        uint256 threshold = _minimumSuccessfulGas(callData, 100_000, 300_000);

        (bool success,) = address(_harness).call{ gas: threshold }(callData);
        assertTrue(success);
        bytes memory returndata;
        (success, returndata) = address(_harness).call{ gas: threshold - 1 }(callData);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), LibRootBootstrapV1.BootstrapInsufficientCallGas.selector);
    }

    function test_callCreate3ProxyExact_RevertWhen_ExactReturndataCopyWouldConsumeReserve()
        external
    {
        uint256 reserve = 500_000;
        bytes memory callData = abi.encodeCall(
            LibRootBootstrapV1Harness.callCreate3ProxyExactGasAfter,
            (address(_target), _returnInput(_LARGE_EXACT_RETURN, 100_000), _LARGE_EXACT_RETURN)
        );

        (bool success, bytes memory returndata) = address(_harness).call{ gas: 1_100_000 }(callData);

        if (success) {
            (uint256 gasAfter,) = abi.decode(returndata, (uint256, bytes32));
            assertLt(gasAfter, reserve);
        }
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), LibRootBootstrapV1.BootstrapPostCallGasTooLow.selector);
    }

    function test_callCreate3ProxyExact_PreservesReserveAfterLargeExactReturndataCopy() external {
        uint256 reserve = 500_000;
        (uint256 gasAfter, bytes32 outputHash) = _harness.callCreate3ProxyExactGasAfter{
            gas: 1_500_000
        }(address(_target), _returnInput(_LARGE_EXACT_RETURN, 450_000), _LARGE_EXACT_RETURN);

        assertGe(gasAfter, reserve);
        assertTrue(outputHash != bytes32(0));
    }

    function test_callCreate3ProxyExact_RevertWithoutCopyWhen_ReturndataIsUnexpectedlyHuge()
        external
    {
        uint256 unexpectedLength = 1_048_576;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapReturnLengthMismatch.selector,
                address(_target),
                unexpectedLength,
                32
            )
        );
        _harness.callCreate3ProxyExactNoReturn(
            address(_target), _returnInput(unexpectedLength, type(uint256).max), 32
        );
    }

    function test_callCreate3ProxyExact_CalleeOogRollsBackTargetState() external {
        StatefulOogTarget target = new StatefulOogTarget();
        bytes memory input = hex"deadbeef";
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapExternalCallFailed.selector,
                address(target),
                bytes4(input)
            )
        );
        _harness.callCreate3ProxyExactNoReturn{ gas: 800_000 }(address(target), input, 0);
        assertEq(target.calls(), 0);
    }

    function test_callCreate3ProxyExact_ExternalGasThresholdAndThresholdMinusOne() external {
        bytes memory callData = abi.encodeCall(
            LibRootBootstrapV1Harness.callCreate3ProxyExactNoReturn,
            (address(_target), _returnInput(0, type(uint256).max), 0)
        );
        uint256 threshold = _minimumSuccessfulGas(callData, 500_000, 700_000);

        (bool success,) = address(_harness).call{ gas: threshold }(callData);
        assertTrue(success);
        bytes memory returndata;
        (success, returndata) = address(_harness).call{ gas: threshold - 1 }(callData);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), LibRootBootstrapV1.BootstrapExternalCallFailed.selector);
    }

    function _returnInput(
        uint256 _returnLength,
        uint256 _gasFloor
    )
        private
        pure
        returns (bytes memory input_)
    {
        return abi.encodeWithSelector(
            bytes4(keccak256("returnExact(uint256,uint256)")), _returnLength, _gasFloor
        );
    }

    function _minimumSuccessfulGas(
        bytes memory _callData,
        uint256 _low,
        uint256 _high
    )
        private
        returns (uint256 threshold_)
    {
        while (_low < _high) {
            uint256 midpoint = (_low + _high) / 2;
            (bool success,) = address(_harness).call{ gas: midpoint }(_callData);
            if (success) {
                _high = midpoint;
            } else {
                _low = midpoint + 1;
            }
        }
        return _low;
    }
}
