// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L1/TaikoData.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

struct MyStruct {
    uint256 id;
    uint256 l1Height;
    bytes32 l1Hash;
    uint64 gasLimit;
    uint64 timestamp;
}

contract FooBar {
    function loadBlockMetadata_1(bytes memory data) public {
        MyStruct memory meta = abi.decode(data, (MyStruct));
    }

    function loadBlockMetadata_2(bytes calldata data) public {
        MyStruct memory meta = abi.decode(data, (MyStruct));
    }

    function loadBlockMetadata_3(MyStruct memory data) public {}

    function loadBlockMetadata_4(MyStruct calldata data) public {}

    function loadBlockMetadata_5(bytes calldata data) public {
        MyStruct memory meta;
        meta.id = uint256(bytes32(data[0:32]));
        meta.l1Height = uint256(bytes32(data[32:64]));
        meta.l1Hash = bytes32(data[64:96]);
        meta.gasLimit = uint64(bytes8(data[96:104]));
        meta.timestamp = uint64(bytes8(data[104:112]));
    }

    function loadBlockMetadata_6() public {
        MyStruct memory meta;
        uint256 a;
        assembly {
            a := calldatasize()
        }
        require(a == 84 + 32, "aaa");

        assembly {
            a := calldataload(4)
        }
        meta.id = a;
        assembly {
            a := calldataload(36)
        }
        meta.l1Height = a;
        assembly {
            a := calldataload(68)
        }
        meta.l1Hash = bytes32(a);
        assembly {
            a := calldataload(84)
        }
        meta.gasLimit = uint64(uint256((a << 128) >> (128 + 64)));
        meta.timestamp = uint64(uint256((a << (128 + 64)) >> (128 + 64)));
    }

    function return_1() public returns (TaikoData.BlockMetadata memory meta) {
        meta = TaikoData.BlockMetadata({
            id: 1,
            l1Height: 1,
            l1Hash: bytes32(uint256(1)),
            beneficiary: address(this),
            txListHash: bytes32(uint256(1)),
            gasLimit: 1,
            mixHash: bytes32(uint256(1)),
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
            mixHash: bytes32(uint256(1)),
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

    // ------
    function hashKey_1(
        uint chainId,
        string memory name
    ) public view returns (bytes32) {
        return keccak256(bytes(string.concat(Strings.toString(chainId), name)));
    }

    function hashKey_2(
        uint chainId,
        string memory name
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(chainId, name));
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

        foobar.hashKey_1(123, "abc");
        foobar.hashKey_2(123, "abc");

        MyStruct memory meta = MyStruct({
            id: 123,
            l1Height: 456,
            l1Hash: blockhash(block.number - 1),
            gasLimit: 333,
            timestamp: 999
        });
        {
            bytes memory b = abi.encode(meta);
            foobar.loadBlockMetadata_1(b);
            foobar.loadBlockMetadata_2(b);
            foobar.loadBlockMetadata_3(meta);
            foobar.loadBlockMetadata_4(meta); // best
        }
        {
            bytes memory b = bytes.concat(
                bytes32(meta.id),
                bytes32(meta.l1Height),
                meta.l1Hash,
                bytes8(meta.gasLimit),
                bytes8(meta.timestamp)
            );

            foobar.loadBlockMetadata_5(b);

            bytes memory c = bytes.concat(
                FooBar.loadBlockMetadata_6.selector,
                b
            );

            address(foobar).call(c);
        }
    }
}
