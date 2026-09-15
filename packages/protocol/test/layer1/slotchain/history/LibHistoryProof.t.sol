// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibHistoryProof } from "../../../../contracts/layer1/slotchain/libs/LibHistoryProof.sol";
import { LibCanonicalRLP } from "../../../../contracts/shared/slotchain/libs/LibCanonicalRLP.sol";
import { CanonicalTrieFixtures } from "../../../shared/slotchain/utils/CanonicalTrieFixtures.sol";
import { Test } from "forge-std/src/Test.sol";

contract HistoryProofHarness {
    function tryReadBeaconRoot(
        uint64 _timestamp,
        bytes32 _runtimeHash
    )
        external
        view
        returns (bool present_, bytes32 root_)
    {
        return LibHistoryProof.tryReadBeaconRoot(_timestamp, _runtimeHash);
    }

    function authenticateExecutionHeader(
        bytes calldata _header,
        uint64 _number,
        uint64 _timestamp,
        bytes32 _parentBeaconRoot,
        uint64 _firstSupported,
        bytes32 _runtimeHash
    )
        external
        view
        returns (LibHistoryProof.ExecutionHeader memory header_)
    {
        return LibHistoryProof.authenticateExecutionHeader(
            _header, _number, _timestamp, _parentBeaconRoot, _firstSupported, _runtimeHash
        );
    }

    function authenticateStored(
        bytes calldata _header,
        uint64 _number,
        bytes32 _hash
    )
        external
        pure
        returns (LibHistoryProof.ExecutionHeader memory header_)
    {
        return LibHistoryProof.authenticateStoredExecutionHeader(_header, _number, _hash);
    }
}

contract ExactSystemReadMock {
    uint256 private immutable _expectedInput;
    bytes32 private immutable _returnWord;

    constructor(uint256 _input, bytes32 _word) {
        _expectedInput = _input;
        _returnWord = _word;
    }

    fallback() external {
        uint256 expectedInput = _expectedInput;
        bytes32 returnWord = _returnWord;
        assembly ("memory-safe") {
            if iszero(eq(calldatasize(), 32)) { revert(0, 0) }
            if iszero(eq(calldataload(0), expectedInput)) { revert(0, 0) }
            // The reviewed call gives exactly a 50,000-gas cap. The dispatcher consumes a small
            // fixed prefix before this assertion.
            if gt(gas(), 50000) { revert(0, 0) }
            if lt(gas(), 48000) { revert(0, 0) }
            mstore(0, returnWord)
            return(0, 32)
        }
    }
}

contract MalformedSystemReadMock {
    uint8 private immutable _mode;

    constructor(uint8 mode_) {
        _mode = mode_;
    }

    fallback() external {
        uint8 mode = _mode;
        assembly ("memory-safe") {
            if eq(mode, 0) { revert(0, 0) }
            mstore(0, 0x1234)
            if eq(mode, 1) { return(0, 31) }
            if eq(mode, 2) { return(0, 33) }
            if eq(mode, 3) {
                mstore(0, 0)
                return(0, 32)
            }
            invalid()
        }
    }
}

contract LibHistoryProofTest is Test {
    address private constant _BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address private constant _HISTORY = 0x0000F90827F1C53a10cb7A02335B175320002935;

    HistoryProofHarness private harness;

    function setUp() external {
        harness = new HistoryProofHarness();
    }

    function test_tryReadBeaconRoot_UsesExactFixedAddressCalldataGasAndReturn() external {
        uint64 timestamp = 1_900_000_012;
        bytes32 root = keccak256("beacon-root");
        _etch(_BEACON_ROOTS, address(new ExactSystemReadMock(timestamp, root)));

        (bool present, bytes32 returned) =
            harness.tryReadBeaconRoot(timestamp, _BEACON_ROOTS.codehash);
        assertTrue(present);
        assertEq(returned, root);

        vm.expectRevert(
            abi.encodeWithSelector(LibHistoryProof.SystemRuntimeMismatch.selector, _BEACON_ROOTS)
        );
        harness.tryReadBeaconRoot(timestamp, bytes32(uint256(_BEACON_ROOTS.codehash) ^ 1));
    }

    function test_tryReadBeaconRoot_OnlyRevertMeansAbsentAndMalformedSuccessIsFatal() external {
        uint64 timestamp = 1_900_000_012;
        _etch(_BEACON_ROOTS, address(new MalformedSystemReadMock(0)));
        (bool present, bytes32 root) = harness.tryReadBeaconRoot(timestamp, _BEACON_ROOTS.codehash);
        assertFalse(present);
        assertEq(root, bytes32(0));

        _etch(_BEACON_ROOTS, address(new MalformedSystemReadMock(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibHistoryProof.SystemReadLengthMismatch.selector, _BEACON_ROOTS, 31, 32
            )
        );
        harness.tryReadBeaconRoot(timestamp, _BEACON_ROOTS.codehash);

        _etch(_BEACON_ROOTS, address(new MalformedSystemReadMock(2)));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibHistoryProof.SystemReadLengthMismatch.selector, _BEACON_ROOTS, 33, 32
            )
        );
        harness.tryReadBeaconRoot(timestamp, _BEACON_ROOTS.codehash);

        _etch(_BEACON_ROOTS, address(new MalformedSystemReadMock(3)));
        vm.expectRevert(LibHistoryProof.InvalidBeaconRootReturn.selector);
        harness.tryReadBeaconRoot(timestamp, _BEACON_ROOTS.codehash);

        vm.expectRevert(LibHistoryProof.InvalidBeaconRootTimestamp.selector);
        harness.tryReadBeaconRoot(0, _BEACON_ROOTS.codehash);
    }

    function test_authenticateExecutionHeader_JoinsExactEip2935ReadAndHeaderFields() external {
        vm.roll(10_000);
        uint64 number = 9000;
        uint64 timestamp = 1_900_000_012;
        bytes32 parentHash = keccak256("parent");
        bytes32 parentBeaconRoot = keccak256("parent-beacon");
        bytes memory header = _header(number, timestamp, parentHash, parentBeaconRoot, 0, 20);
        bytes32 headerHash = keccak256(header);
        _etch(_HISTORY, address(new ExactSystemReadMock(number, headerHash)));

        LibHistoryProof.ExecutionHeader memory decoded = harness.authenticateExecutionHeader(
            header, number, timestamp, parentBeaconRoot, 1809, _HISTORY.codehash
        );
        assertEq(decoded.blockHash, headerHash);
        assertEq(decoded.parentHash, parentHash);
        assertEq(decoded.stateRoot, keccak256("state-root"));
        assertEq(decoded.blockNumber, number);
        assertEq(decoded.timestamp, timestamp);
        assertEq(decoded.parentBeaconBlockRoot, parentBeaconRoot);
    }

    function test_historyRange_AcceptsBothEndpointsAndSaturatesBelowServeWindow() external {
        vm.roll(10_000);
        _authenticateAt(1809, 1809);
        _authenticateAt(9999, 1809);

        bytes memory header =
            _header(1808, 1_900_000_012, keccak256("parent"), keccak256("beacon"), 0, 20);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibHistoryProof.HistoricalBlockOutsideRange.selector, 1808, 1809, 10_000
            )
        );
        harness.authenticateExecutionHeader(
            header, 1808, 1_900_000_012, keccak256("beacon"), 1809, _HISTORY.codehash
        );

        header = _header(10_000, 1_900_000_012, keccak256("parent"), keccak256("beacon"), 0, 20);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibHistoryProof.HistoricalBlockOutsideRange.selector, 10_000, 1809, 10_000
            )
        );
        harness.authenticateExecutionHeader(
            header, 10_000, 1_900_000_012, keccak256("beacon"), 1809, _HISTORY.codehash
        );

        vm.roll(100);
        _authenticateAt(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(LibHistoryProof.HistoricalBlockOutsideRange.selector, 0, 0, 100)
        );
        harness.authenticateExecutionHeader(
            _header(1, 1, bytes32(uint256(1)), bytes32(uint256(2)), 0, 20),
            0,
            1,
            bytes32(uint256(2)),
            0,
            _HISTORY.codehash
        );
    }

    function test_executionHeader_RequiresCanonical20To32StringFieldsAndExactWidths() external {
        uint64 number = 100;
        uint64 timestamp = 1_900_000_012;
        bytes32 parent = keccak256("parent");
        bytes32 beacon = keccak256("beacon");

        bytes memory header20 = _header(number, timestamp, parent, beacon, 0, 20);
        harness.authenticateStored(header20, number, keccak256(header20));
        bytes memory header32 = _header(number, timestamp, parent, beacon, 0, 32);
        harness.authenticateStored(header32, number, keccak256(header32));

        bytes memory header19 = _header(number, timestamp, parent, beacon, 0, 19);
        vm.expectRevert(LibHistoryProof.InvalidExecutionHeaderFieldCount.selector);
        harness.authenticateStored(header19, number, keccak256(header19));
        bytes memory header33 = _header(number, timestamp, parent, beacon, 0, 33);
        vm.expectRevert(LibHistoryProof.InvalidExecutionHeaderFieldCount.selector);
        harness.authenticateStored(header33, number, keccak256(header33));

        bytes memory wrongParentWidth = _header(number, timestamp, parent, beacon, 0, 20);
        // The first field starts after the two-byte long-list prefix and uses 0xa0.
        wrongParentWidth[2] = 0x9f;
        vm.expectRevert();
        harness.authenticateStored(wrongParentWidth, number, keccak256(wrongParentWidth));
    }

    function test_executionHeader_AcceptsExact2048AndRejects2049ByteBoundary() external {
        bytes memory exact =
            _header(100, 1_900_000_012, keccak256("parent"), keccak256("beacon"), 1871, 20);
        assertEq(exact.length, 2048);
        harness.authenticateStored(exact, 100, keccak256(exact));

        bytes memory oversized = bytes.concat(exact, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(LibHistoryProof.InvalidExecutionHeaderLength.selector, 2049)
        );
        harness.authenticateStored(oversized, 100, keccak256(oversized));
    }

    function test_authenticateExecutionHeader_RejectsMalformedSystemReturnAndContextMismatch()
        external
    {
        vm.roll(10_000);
        uint64 number = 9000;
        uint64 timestamp = 1_900_000_012;
        bytes32 beacon = keccak256("beacon");
        bytes memory header = _header(number, timestamp, keccak256("parent"), beacon, 0, 20);

        _etch(_HISTORY, address(new MalformedSystemReadMock(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibHistoryProof.SystemReadLengthMismatch.selector, _HISTORY, 31, 32
            )
        );
        harness.authenticateExecutionHeader(
            header, number, timestamp, beacon, 1809, _HISTORY.codehash
        );

        _etch(_HISTORY, address(new MalformedSystemReadMock(3)));
        vm.expectRevert(
            abi.encodeWithSelector(LibHistoryProof.HistoricalBlockHashMismatch.selector, number)
        );
        harness.authenticateExecutionHeader(
            header, number, timestamp, beacon, 1809, _HISTORY.codehash
        );

        _etch(_HISTORY, address(new ExactSystemReadMock(number, keccak256(header))));
        vm.expectRevert(LibHistoryProof.ExecutionHeaderContextMismatch.selector);
        harness.authenticateExecutionHeader(
            header, number, timestamp + 1, beacon, 1809, _HISTORY.codehash
        );
    }

    function _authenticateAt(uint64 _number, uint64 _firstSupported) private {
        uint64 timestamp = 1_900_000_012;
        bytes32 beacon = keccak256(abi.encodePacked("beacon", _number));
        bytes memory header = _header(_number, timestamp, keccak256("parent"), beacon, 0, 20);
        _etch(_HISTORY, address(new ExactSystemReadMock(_number, keccak256(header))));
        harness.authenticateExecutionHeader(
            header, _number, timestamp, beacon, _firstSupported, _HISTORY.codehash
        );
    }

    function _header(
        uint64 _number,
        uint64 _timestamp,
        bytes32 _parent,
        bytes32 _parentBeaconRoot,
        uint256 _paddingLength,
        uint256 _fieldCount
    )
        private
        pure
        returns (bytes memory header_)
    {
        bytes[] memory fields = new bytes[](_fieldCount);
        for (uint256 i; i < _fieldCount; ++i) {
            fields[i] = hex"80";
        }
        if (_fieldCount > 0) fields[0] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(_parent));
        if (_fieldCount > 1) {
            fields[1] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256("ommers")));
        }
        if (_fieldCount > 2) {
            fields[2] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(address(0x1234)));
        }
        if (_fieldCount > 3) {
            fields[3] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256("state-root")));
        }
        if (_fieldCount > 8) fields[8] = _rlpUint(_number);
        if (_fieldCount > 11) fields[11] = _rlpUint(_timestamp);
        if (_fieldCount > 12) {
            fields[12] = CanonicalTrieFixtures.rlpBytes(new bytes(_paddingLength));
        }
        if (_fieldCount > 19) {
            fields[19] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(_parentBeaconRoot));
        }
        return CanonicalTrieFixtures.rlpList(fields);
    }

    function _rlpUint(uint256 _value) private pure returns (bytes memory encoded_) {
        require(_value != 0, "fixture zero");
        bytes32 word = bytes32(_value);
        uint256 first;
        while (word[first] == 0) ++first;
        bytes memory minimal = new bytes(32 - first);
        for (uint256 i; i < minimal.length; ++i) {
            minimal[i] = word[first + i];
        }
        return CanonicalTrieFixtures.rlpBytes(minimal);
    }

    function _etch(address _target, address _source) private {
        vm.etch(_target, _source.code);
    }
}
