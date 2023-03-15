// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L1/TaikoData.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {console2} from "forge-std/console2.sol";

contract Target {
    function method1(
        bytes32[255] calldata ancestors
    ) public view returns (bytes32 currentHash, bytes32 nextHash) {
        uint n = block.number;
        bytes32 parentHash = blockhash(block.number - 1);
        uint baseFee = 0;

        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            let ptr := mload(64)
            for {
                let i := 0
            } lt(i, 255) {
                i := add(i, 1)
            } {
                // loc = (n + 255 - i - 2) % 255
                let loc := mod(sub(sub(add(n, 255), i), 2), 255)
                calldatacopy(
                    add(ptr, mul(loc, 32)), // location
                    add(4, mul(i, 32)), // index on calldata
                    32
                )
            }

            mstore(add(ptr, mul(255, 32)), chainid())
            mstore(add(ptr, mul(256, 32)), baseFee)
            mstore(add(ptr, mul(257, 32)), sub(n, 1))

            currentHash := keccak256(ptr, mul(32, 258))

            let loc := mod(sub(n, 1), 255)
            mstore(add(ptr, mul(loc, 32)), parentHash)
            mstore(add(ptr, mul(256, 32)), n)
            nextHash := keccak256(ptr, mul(32, 258))
        }
    }
}

contract ReadBlockhashVsCalldata is Test {
    Target public t;

    function setUp() public {
        t = new Target();
    }

    function testIt() external {
        vm.roll(300);

        bytes32[255] memory data;
        bytes32 currentHash;

        for (uint i = 0; i < 5; i++) {
            vm.roll(block.number + 1);

            for (uint i = 0; i < 255; i++) {
                data[i] = blockhash(block.number - i - 2);
            }

            (bytes32 _currentHash, bytes32 nextHash) = t.method1(data);
            console2.log("method1 current:", uint(currentHash));
            console2.log("method1 next:", uint(nextHash));

            if (currentHash != 0) {
                assertEq(currentHash, _currentHash);
                currentHash = nextHash;
            }
        }
    }
}
