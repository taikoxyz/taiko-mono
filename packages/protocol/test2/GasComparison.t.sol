// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L1/TaikoData.sol";

contract FooBar {
    function return_1() public returns (TaikoData.BlockMetadata memory meta) {
        meta = TaikoData.BlockMetadata({
            id: 1,
            l1Height: 1,
            l1Hash: bytes32(uint256(1)),
            beneficiary: address(this),
            txListHash: bytes32(uint256(1)),
            gasLimit: 1,
            mixHash: 1,
            timestamp: 1
        });
    }

    function return_2() public {
        TaikoData.BlockMetadata memory meta = TaikoData.BlockMetadata({
            id: 1,
            l1Height: 1,
            l1Hash: bytes32(uint256(1)),
            beneficiary: address(this),
            txListHash: bytes32(uint256(1)),
            gasLimit: 1,
            mixHash: 1,
            timestamp: 1
        });
    }

    //------
    function hashString_1(string memory str) public returns (bytes32 hash) {
        assembly {
            hash := keccak256(add(str, 32), mload(str))
        }
    }

    function hashString_2(string memory str) public returns (bytes32 hash) {
        hash = keccak256(bytes(str));
    }

    //------

    function hashTwo_1(address a, bytes32 b) public returns (bytes32 hash) {
        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            let input := mload(0x40)

            // Store the app address and signal bytes32 value in the allocated memory
            mstore(input, a)
            mstore(add(input, 0x20), b)

            hash := keccak256(input, 0x40)

            // Free the memory allocated for the input
            mstore(0x40, add(input, 0x60))
        }
    }

    function hashTwo_2(address a, bytes32 b) public returns (bytes32 hash) {
        hash = keccak256(bytes.concat(bytes32(uint256(uint160(a))), b));
    }

    //------

    function increment_1(uint count) public {
        uint a;
        for (uint i = 0; i < count; i++) {
            a += i;
        }
    }

    function increment_2(uint count) public {
        uint a;
        for (uint i = 0; i < count; ++i) {
            a += i;
        }
    }

    function increment_3(uint count) public {
        uint a;
        for (uint i = 0; i < count; ) {
            a += i;
            unchecked {
                i++;
            }
        }
    }

    function increment_4(uint count) public {
        uint a;
        for (uint i = 0; i < count; ) {
            a += i;
            unchecked {
                ++i;
            }
        }
    }
}

contract GasComparisonTest is Test {
    FooBar foobar;

    function setUp() public {
        foobar = new FooBar();
    }

    function testCompareHashString(uint count) external {
        vm.assume(count > 10 && count < 1000);
        string memory str = string(new bytes(count));
        assertEq(
            foobar.hashString_1(str),
            foobar.hashString_2(str) //best
        );

        address a = address(this);
        bytes32 b = blockhash(block.number - 1);
        assertEq(
            foobar.hashTwo_1(a, b), //best
            foobar.hashTwo_2(a, b)
        );

        foobar.increment_1(count);
        foobar.increment_2(count);
        foobar.increment_3(count); // best
        foobar.increment_4(count);

        foobar.return_1();
        foobar.return_2(); // cheaper
    }
}
