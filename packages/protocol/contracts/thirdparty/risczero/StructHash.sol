// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { reverseByteOrderUint16 } from "./Util.sol";

/// @notice Structural hashing routines used for RISC Zero data structures.
/// @dev
/// StructHash implements hashing for structs, incorporating type tags for domain separation.
/// The goals of this library are:
/// * Collision resistance: it should not be possible to find two semantically distinct values that
///   produce the same digest.
/// * Simplicity: implementations should be simple to understand and write, as these methods must
///   be implemented in multiple languages and environments, including zkSNARK circuits.
/// * Incremental openings: it should be possible to incrementally open a nested struct without
///   needing to open (very many) extra fields (i.e. the struct should be "Merkle-ized").
library StructHash {
    using SafeCast for uint256;

    // @notice Compute the struct digest with the given tag digest and digest fields down.
    function taggedStruct(
        bytes32 tagDigest,
        bytes32[] memory down
    )
        internal
        pure
        returns (bytes32)
    {
        bytes memory data = new bytes(0);
        return taggedStruct(tagDigest, down, data);
    }

    // @notice Compute the struct digest with the given tag digest, digest fields down, and data.
    function taggedStruct(
        bytes32 tagDigest,
        bytes32[] memory down,
        bytes memory data
    )
        internal
        pure
        returns (bytes32)
    {
        uint16 downLen = down.length.toUint16();
        // swap the byte order to encode as little-endian.
        bytes2 downLenLE = bytes2((downLen << 8) | (downLen >> 8));
        return sha256(abi.encodePacked(tagDigest, down, data, downLenLE));
    }

    // @notice Add an element (head) to the incremental hash of a list (tail).
    function taggedListCons(
        bytes32 tagDigest,
        bytes32 head,
        bytes32 tail
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory down = new bytes32[](2);
        down[0] = head;
        down[1] = tail;
        return taggedStruct(tagDigest, down);
    }

    // @notice Hash the list by using taggedListCons to repeatedly add to the head of the list.
    function taggedList(bytes32 tagDigest, bytes32[] memory list) internal pure returns (bytes32) {
        bytes32 curr = bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);
        for (uint256 i = 0; i < list.length; i++) {
            curr = taggedListCons(tagDigest, list[list.length - 1 - i], curr);
        }
        return curr;
    }
}
