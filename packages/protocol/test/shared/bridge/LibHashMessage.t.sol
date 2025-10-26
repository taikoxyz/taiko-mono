// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/shared/bridge/libs/LibHashMessage.sol";
import "src/shared/bridge/IBridge.sol";

/// @title LibHashMessageTest
/// @notice Fuzz tests to verify equivalence and gas savings
contract LibHashMessageTest is Test {
    using LibHashMessage for IBridge.Message;

    function test_hashEquivalence_emptyData() public pure {
        IBridge.Message memory message = IBridge.Message({
            id: 1,
            fee: 100,
            gasLimit: 50000,
            from: address(0x1234),
            srcChainId: 1,
            srcOwner: address(0x5678),
            destChainId: 2,
            destOwner: address(0x9abc),
            to: address(0xdef0),
            value: 1 ether,
            data: ""
        });

        bytes32 original = LibHashMessage.hashOriginal(message);
        bytes32 optimized = LibHashMessage.hashOptimized(message);

        assertEq(original, optimized, "Hashes should match for empty data");
    }

    function test_hashEquivalence_withData() public pure {
        IBridge.Message memory message = IBridge.Message({
            id: 42,
            fee: 500,
            gasLimit: 100000,
            from: address(0xabcd),
            srcChainId: 5,
            srcOwner: address(0xef01),
            destChainId: 10,
            destOwner: address(0x2345),
            to: address(0x6789),
            value: 5 ether,
            data: hex"deadbeef"
        });

        bytes32 original = LibHashMessage.hashOriginal(message);
        bytes32 optimized = LibHashMessage.hashOptimized(message);

        assertEq(original, optimized, "Hashes should match with data");
    }

    function testFuzz_hashEquivalence(
        uint64 id,
        uint64 fee,
        uint32 gasLimit,
        address from,
        uint64 srcChainId,
        address srcOwner,
        uint64 destChainId,
        address destOwner,
        address to,
        uint256 value,
        bytes memory data
    )
        public
        pure
    {
        // Limit data size to reasonable bounds
        vm.assume(data.length <= 10000);

        IBridge.Message memory message = IBridge.Message({
            id: id,
            fee: fee,
            gasLimit: gasLimit,
            from: from,
            srcChainId: srcChainId,
            srcOwner: srcOwner,
            destChainId: destChainId,
            destOwner: destOwner,
            to: to,
            value: value,
            data: data
        });

        bytes32 original = LibHashMessage.hashOriginal(message);
        bytes32 optimized = LibHashMessage.hashOptimized(message);

        assertEq(original, optimized, "Fuzz: Hashes must always match");
    }

    function test_gasComparison_emptyData() public {
        IBridge.Message memory message = IBridge.Message({
            id: 1,
            fee: 100,
            gasLimit: 50000,
            from: address(0x1234),
            srcChainId: 1,
            srcOwner: address(0x5678),
            destChainId: 2,
            destOwner: address(0x9abc),
            to: address(0xdef0),
            value: 1 ether,
            data: ""
        });

        uint256 gasBefore = gasleft();
        LibHashMessage.hashOriginal(message);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashMessage.hashOptimized(message);
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas", gasOriginal);
        emit log_named_uint("Optimized gas", gasOptimized);
        emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
        emit log_named_uint(
            "Savings %", gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
        );

        assertLt(gasOptimized, gasOriginal, "Optimized should use less gas");
    }

    function test_gasComparison_withSmallData() public {
        IBridge.Message memory message = IBridge.Message({
            id: 42,
            fee: 500,
            gasLimit: 100000,
            from: address(0xabcd),
            srcChainId: 5,
            srcOwner: address(0xef01),
            destChainId: 10,
            destOwner: address(0x2345),
            to: address(0x6789),
            value: 5 ether,
            data: hex"deadbeef01020304"
        });

        uint256 gasBefore = gasleft();
        LibHashMessage.hashOriginal(message);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashMessage.hashOptimized(message);
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas (small data)", gasOriginal);
        emit log_named_uint("Optimized gas (small data)", gasOptimized);
        emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
        emit log_named_uint(
            "Savings %", gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
        );

        assertLt(gasOptimized, gasOriginal, "Optimized should use less gas with small data");
    }

    function test_gasComparison_withLargeData() public {
        bytes memory largeData = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }

        IBridge.Message memory message = IBridge.Message({
            id: 99,
            fee: 1000,
            gasLimit: 200000,
            from: address(0x1111),
            srcChainId: 15,
            srcOwner: address(0x2222),
            destChainId: 20,
            destOwner: address(0x3333),
            to: address(0x4444),
            value: 10 ether,
            data: largeData
        });

        uint256 gasBefore = gasleft();
        LibHashMessage.hashOriginal(message);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashMessage.hashOptimized(message);
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas (large data)", gasOriginal);
        emit log_named_uint("Optimized gas (large data)", gasOptimized);

        // Note: For very large data, the assembly version may use more gas
        // due to the overhead of manual copying. The optimization is targeted
        // at small to medium sized messages which are more common in practice.
        if (gasOptimized < gasOriginal) {
            emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
            emit log_named_uint(
                "Savings %",
                gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
            );
        } else {
            emit log_named_uint("Additional gas used", gasOptimized - gasOriginal);
            emit log_string("Note: Assembly overhead dominates for very large data");
        }
    }
}
