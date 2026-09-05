// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    INativeEthSinkV2
} from "../../../../contracts/shared/slotchain/iface/INativeEthSinkV2.sol";
import { LibExactCall } from "../../../../contracts/shared/slotchain/libs/LibExactCall.sol";
import { Test } from "forge-std/src/Test.sol";

contract ExactCallHarness {
    function staticcallExact(
        address _target,
        bytes32 _runtimeHash,
        bytes calldata _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        external
        view
        returns (bytes memory output_, uint256 gasAfter_)
    {
        output_ = LibExactCall.staticcallExact(
            _target, _runtimeHash, _input, _gasLimit, _returnLength, _postCopyReserve
        );
        gasAfter_ = gasleft();
    }

    function callExact(
        address _target,
        bytes32 _runtimeHash,
        uint256 _value,
        bytes calldata _input,
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        external
        payable
        returns (bytes memory output_, uint256 gasAfter_)
    {
        output_ = LibExactCall.callExact(
            _target, _runtimeHash, _value, _input, _gasLimit, _returnLength, _postCopyReserve
        );
        gasAfter_ = gasleft();
    }

    function requireConfiguration(
        address _target,
        bytes32 _runtimeHash,
        bytes4 _selector,
        bytes32 _configurationHash,
        uint256 _gasLimit,
        uint256 _postCopyReserve
    )
        external
        view
    {
        LibExactCall.requireConfiguration(
            _target, _runtimeHash, _selector, _configurationHash, _gasLimit, _postCopyReserve
        );
    }

    function minimumCallerGas(
        uint256 _gasLimit,
        uint256 _returnLength,
        uint256 _postCopyReserve
    )
        external
        pure
        returns (uint256 minimum_)
    {
        return LibExactCall.minimumCallerGas(_gasLimit, _returnLength, _postCopyReserve);
    }

    function decodeWords(bytes calldata _raw)
        external
        pure
        returns (
            address address_,
            bytes4 magic_,
            bool bool_,
            uint8 u8_,
            uint16 u16_,
            uint32 u32_,
            uint64 u64_,
            uint192 u192_
        )
    {
        bytes memory raw = _raw;
        return (
            LibExactCall.addressWord(raw, 0),
            LibExactCall.bytes4Word(raw, 1),
            LibExactCall.boolWord(raw, 2),
            LibExactCall.u8Word(raw, 3),
            LibExactCall.u16Word(raw, 4),
            LibExactCall.u32Word(raw, 5),
            LibExactCall.u64Word(raw, 6),
            LibExactCall.u192Word(raw, 7)
        );
    }
}

contract ExactCallRecorder {
    bytes32 public constant RESULT = keccak256("exact-call-result");

    bytes public lastCalldata;
    uint256 public lastValue;
    uint256 public lastEntryGas;
    address public lastCaller;

    fallback(bytes calldata _input) external payable returns (bytes memory output_) {
        uint256 entryGas = gasleft();
        lastCalldata = _input;
        lastValue = msg.value;
        lastEntryGas = entryGas;
        lastCaller = msg.sender;
        return abi.encode(RESULT);
    }

    receive() external payable {
        uint256 entryGas = gasleft();
        lastCalldata = bytes("");
        lastValue = msg.value;
        lastEntryGas = entryGas;
        lastCaller = msg.sender;
    }
}

contract ExactStaticTarget {
    fallback(bytes calldata _input) external returns (bytes memory output_) {
        uint256 entryGas = gasleft();
        return abi.encode(keccak256(_input), entryGas, msg.sender);
    }
}

contract ExactConfigurationTarget {
    bytes32 internal constant CONFIGURATION_HASH = keccak256("exact-configuration");

    function componentConfigHashV2() external pure returns (bytes32 configurationHash_) {
        return CONFIGURATION_HASH;
    }
}

contract AdversarialExactCallTarget {
    fallback(bytes calldata _input) external payable returns (bytes memory output_) {
        uint8 mode = _input.length == 0 ? 0 : uint8(_input[0]);
        if (mode == 0) return bytes("");
        if (mode == 1) {
            assembly ("memory-safe") {
                mstore(0, 0x1234)
                return(0, 31)
            }
        }
        if (mode == 2) {
            assembly ("memory-safe") {
                mstore(0, 0x1234)
                return(0, 33)
            }
        }
        if (mode == 3) revert("target revert");
        if (mode == 4) {
            assembly ("memory-safe") {
                return(0, 0x40000)
            }
        }
        if (mode == 5) {
            assembly ("memory-safe") {
                revert(0, 0x40000)
            }
        }
        if (mode == 6) {
            assembly ("memory-safe") {
                invalid()
            }
        }
        if (mode == 7) return abi.encode(uint256(2));
        if (mode == 8) {
            uint256 entryGas = gasleft();
            while (gasleft() > 6000) { }
            return abi.encode(entryGas);
        }
        return abi.encode(keccak256(_input));
    }
}

contract MalformedConfigurationTarget {
    bytes32 private immutable _configurationHash;
    uint256 private immutable _returnLength;

    constructor(bytes32 _hash, uint256 _length) {
        _configurationHash = _hash;
        _returnLength = _length;
    }

    fallback(bytes calldata) external returns (bytes memory) {
        bytes32 hash = _configurationHash;
        uint256 length = _returnLength;
        assembly ("memory-safe") {
            mstore(0, hash)
            return(0, length)
        }
    }
}

contract StatefulMalformedReturnTarget {
    uint256 public calls;

    fallback() external payable {
        ++calls;
        assembly ("memory-safe") {
            mstore(0, 0x1234)
            return(0, 31)
        }
    }
}

contract NativeEthSinkV2Mock is INativeEthSinkV2 {
    uint256 public received;

    receive() external payable {
        received += msg.value;
    }
}

contract LibExactCallTest is Test {
    ExactCallHarness private _harness;

    function setUp() public {
        _harness = new ExactCallHarness();
        vm.deal(address(_harness), 100 ether);
    }

    function test_callExact_ForwardsExactCalldataValueAndFullGas() external {
        ExactCallRecorder target = new ExactCallRecorder();
        bytes memory input = hex"112233445566778899";
        uint256 gasLimit = 150_000;
        uint256 reserve = 40_000;

        (bytes memory output, uint256 gasAfter) = _harness.callExact(
            address(target), address(target).codehash, 3 ether, input, gasLimit, 32, reserve
        );

        assertEq(output, abi.encode(target.RESULT()));
        assertEq(target.lastCalldata(), input);
        assertEq(target.lastValue(), 3 ether);
        assertEq(target.lastCaller(), address(_harness));
        // EVM CALL adds the 2,300-gas value stipend to the exact gas operand.
        assertLe(target.lastEntryGas(), gasLimit + 2300);
        assertGt(target.lastEntryGas(), gasLimit + 1800);
        assertGe(gasAfter, reserve);
    }

    function test_staticcallExact_ForwardsExactCalldataAndFullGas() external {
        ExactStaticTarget target = new ExactStaticTarget();
        bytes memory input = hex"aabbccddeeff";
        uint256 gasLimit = 100_000;
        uint256 reserve = 30_000;

        (bytes memory output, uint256 gasAfter) = _harness.staticcallExact(
            address(target), address(target).codehash, input, gasLimit, 96, reserve
        );
        (bytes32 inputHash, uint256 entryGas, address caller) =
            abi.decode(output, (bytes32, uint256, address));
        assertEq(inputHash, keccak256(input));
        assertEq(caller, address(_harness));
        assertLe(entryGas, gasLimit);
        assertGt(entryGas, gasLimit - 500);
        assertGe(gasAfter, reserve);
    }

    function test_staticcallExact_AcceptsExactZeroLengthReturn() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();
        (bytes memory output,) = _harness.staticcallExact(
            address(target), address(target).codehash, hex"00", 50_000, 0, 10_000
        );
        assertEq(output.length, 0);
    }

    function test_staticcallExact_RevertWhen_NoCodeOrRuntimeMismatch() external {
        address noCode = address(0x1234);
        vm.expectPartialRevert(LibExactCall.ExactRuntimeMismatch.selector);
        _harness.staticcallExact(noCode, keccak256(""), hex"00", 50_000, 0, 10_000);

        ExactStaticTarget target = new ExactStaticTarget();
        vm.expectPartialRevert(LibExactCall.ExactRuntimeMismatch.selector);
        _harness.staticcallExact(
            address(target), keccak256("wrong-runtime"), hex"00", 50_000, 0, 10_000
        );

        vm.expectPartialRevert(LibExactCall.ExactRuntimeMismatch.selector);
        _harness.staticcallExact(address(target), bytes32(0), hex"00", 50_000, 0, 10_000);
    }

    function test_requireConfiguration_AcceptsOnlyExactSelectorAndHash() external {
        ExactConfigurationTarget target = new ExactConfigurationTarget();
        bytes32 configurationHash = target.componentConfigHashV2();
        _harness.requireConfiguration(
            address(target),
            address(target).codehash,
            ExactConfigurationTarget.componentConfigHashV2.selector,
            configurationHash,
            50_000,
            10_000
        );

        vm.expectPartialRevert(LibExactCall.ExactConfigurationMismatch.selector);
        _harness.requireConfiguration(
            address(target),
            address(target).codehash,
            ExactConfigurationTarget.componentConfigHashV2.selector,
            keccak256("wrong-configuration"),
            50_000,
            10_000
        );

        vm.expectPartialRevert(LibExactCall.ExactConfigurationMismatch.selector);
        _harness.requireConfiguration(
            address(target), address(target).codehash, bytes4(0), configurationHash, 50_000, 10_000
        );
    }

    function test_requireConfiguration_RevertWhen_ReturnIsShortOrTrailing() external {
        bytes32 configurationHash = keccak256("exact-configuration");
        MalformedConfigurationTarget shortTarget =
            new MalformedConfigurationTarget(configurationHash, 31);
        MalformedConfigurationTarget trailingTarget =
            new MalformedConfigurationTarget(configurationHash, 33);

        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.requireConfiguration(
            address(shortTarget),
            address(shortTarget).codehash,
            bytes4(keccak256("configuration()")),
            configurationHash,
            50_000,
            10_000
        );
        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.requireConfiguration(
            address(trailingTarget),
            address(trailingTarget).codehash,
            bytes4(keccak256("configuration()")),
            configurationHash,
            50_000,
            10_000
        );
    }

    function test_staticcallExact_RevertWhen_ReturnIsShortOrTrailing() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();
        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.staticcallExact(
            address(target), address(target).codehash, hex"01", 50_000, 32, 10_000
        );
        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.staticcallExact(
            address(target), address(target).codehash, hex"02", 50_000, 32, 10_000
        );
    }

    function test_staticcallExact_RevertWithoutCopyingReturnOrRevertBomb() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();

        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.staticcallExact(
            address(target), address(target).codehash, hex"04", 1_000_000, 32, 100_000
        );

        vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
        _harness.staticcallExact(
            address(target), address(target).codehash, hex"05", 1_000_000, 32, 100_000
        );
    }

    function test_callExact_RevertWhen_TargetRevertsOrConsumesFullStipend() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();
        vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
        _harness.callExact(
            address(target), address(target).codehash, 0, hex"03", 80_000, 32, 20_000
        );

        vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
        _harness.callExact(
            address(target), address(target).codehash, 0, hex"06", 80_000, 32, 20_000
        );
    }

    function test_callExact_ReturnLengthFailureRollsBackTargetStateAndValue() external {
        StatefulMalformedReturnTarget target = new StatefulMalformedReturnTarget();
        uint256 harnessBalance = address(_harness).balance;

        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _harness.callExact(
            address(target), address(target).codehash, 3 ether, hex"11223344", 80_000, 32, 20_000
        );

        assertEq(target.calls(), 0);
        assertEq(address(target).balance, 0);
        assertEq(address(_harness).balance, harnessBalance);
    }

    function test_staticcallExact_FullStipendConsumptionPreservesPostCopyReserve() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();
        uint256 gasLimit = 120_000;
        uint256 reserve = 80_000;
        (bytes memory output, uint256 gasAfter) = _harness.staticcallExact(
            address(target), address(target).codehash, hex"08", gasLimit, 32, reserve
        );
        uint256 entryGas = abi.decode(output, (uint256));
        // Instrumented coverage builds add entry probes; the normal optimized build is within
        // 500 gas, while this wider bound keeps the same full-stipend assertion coverage-safe.
        assertGt(entryGas, gasLimit - 5000);
        assertGe(gasAfter, reserve);
    }

    function test_staticcallExact_RevertWhen_Eip150PreflightIsInsufficient() external {
        AdversarialExactCallTarget target = new AdversarialExactCallTarget();
        bytes memory callData = abi.encodeCall(
            ExactCallHarness.staticcallExact,
            (address(target), address(target).codehash, hex"00", 100_000, 0, 50_000)
        );
        (bool success, bytes memory returnData) = address(_harness).call{ gas: 120_000 }(callData);
        assertFalse(success);
        assertEq(bytes4(returnData), LibExactCall.ExactInsufficientCallGas.selector);
    }

    function test_minimumCallerGas_UsesMaximumOfEip150HeadroomAndReserve() external {
        // Reserve dominates the EIP-150 headroom in both examples; the bounds are concurrent
        // requirements and therefore must not be added together.
        assertEq(_harness.minimumCallerGas(63, 0, 7), 10_073);
        assertEq(_harness.minimumCallerGas(64, 33, 7), 10_080);

        // EIP-150 dominates when the requested reserve is smaller.
        assertEq(_harness.minimumCallerGas(126, 0, 1), 10_131);

        // The frozen Source-terminal cold-call budget leaves 64,994 gas outside the shared
        // helper after reserving the exact 2,000,000-gas CALL and 300,000-gas post-copy floor.
        assertEq(_harness.minimumCallerGas(2_000_000, 32, 300_000), 2_310_006);
        assertEq(2_375_000 - _harness.minimumCallerGas(2_000_000, 32, 300_000), 64_994);

        vm.expectRevert(LibExactCall.ExactGasCalculationOverflow.selector);
        _harness.minimumCallerGas(type(uint256).max, 0, 0);
        vm.expectRevert(LibExactCall.ExactGasCalculationOverflow.selector);
        _harness.minimumCallerGas(1, 0, type(uint256).max);
    }

    function test_wordDecoders_RejectDirtyPaddingTrailingAndOutOfBounds() external {
        bytes memory canonical = abi.encode(
            address(0x1234),
            bytes4(0xaabbccdd),
            true,
            uint8(255),
            uint16(65_535),
            uint32(1_000_000),
            uint64(type(uint64).max),
            uint192(type(uint192).max)
        );
        (
            address decodedAddress,
            bytes4 decodedMagic,
            bool decodedBool,
            uint8 decodedU8,
            uint16 decodedU16,
            uint32 decodedU32,
            uint64 decodedU64,
            uint192 decodedU192
        ) = _harness.decodeWords(canonical);
        assertEq(decodedAddress, address(0x1234));
        assertEq(decodedMagic, bytes4(0xaabbccdd));
        assertTrue(decodedBool);
        assertEq(decodedU8, type(uint8).max);
        assertEq(decodedU16, type(uint16).max);
        assertEq(decodedU32, 1_000_000);
        assertEq(decodedU64, type(uint64).max);
        assertEq(decodedU192, type(uint192).max);

        bytes memory dirtyAddress = canonical;
        dirtyAddress[0] = 0x01;
        vm.expectPartialRevert(LibExactCall.ExactMalformedReturnWord.selector);
        _harness.decodeWords(dirtyAddress);

        bytes memory dirtyMagic = canonical;
        dirtyMagic[63] = 0x01;
        vm.expectPartialRevert(LibExactCall.ExactMalformedReturnWord.selector);
        _harness.decodeWords(dirtyMagic);

        bytes memory dirtyBool = canonical;
        dirtyBool[95] = 0x02;
        vm.expectPartialRevert(LibExactCall.ExactMalformedReturnWord.selector);
        _harness.decodeWords(dirtyBool);

        bytes memory trailing = bytes.concat(canonical, hex"00");
        vm.expectPartialRevert(LibExactCall.ExactMalformedReturnWord.selector);
        _harness.decodeWords(trailing);

        vm.expectPartialRevert(LibExactCall.ExactMalformedReturnWord.selector);
        _harness.decodeWords(bytes(""));
    }

    function test_nativeEthSinkV2_AcceptsOnlyEmptyCalldataReceive() external {
        NativeEthSinkV2Mock sink = new NativeEthSinkV2Mock();
        (bool success,) = address(sink).call{ value: 2 ether }("");
        assertTrue(success);
        assertEq(sink.received(), 2 ether);

        (success,) = address(sink).call{ value: 1 ether }(hex"00");
        assertFalse(success);
        assertEq(sink.received(), 2 ether);
    }
}
