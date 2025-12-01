// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposeInputDecoder } from "src/layer1/core/libs/LibProposeInputDecoder.sol";

contract LibProposeInputDecoderTest is Test {
    function test_encode_decode_roundtrip() public {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_234_567,
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 5, numBlobs: 2, offset: 99 }),
            numForcedInclusions: 3
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        assertEq(encoded.length, 14, "encoded length");

        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);
        assertEq(decoded.deadline, input.deadline, "deadline");
        assertEq(decoded.blobReference.blobStartIndex, input.blobReference.blobStartIndex, "blobStartIndex");
        assertEq(decoded.blobReference.numBlobs, input.blobReference.numBlobs, "numBlobs");
        assertEq(decoded.blobReference.offset, input.blobReference.offset, "offset");
        assertEq(decoded.numForcedInclusions, input.numForcedInclusions, "forced inclusions");
    }

    function test_encode_decode_boundaryValues() public {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: type(uint48).max,
            blobReference: LibBlobs.BlobReference({
                blobStartIndex: type(uint16).max,
                numBlobs: type(uint16).max,
                offset: type(uint24).max
            }),
            numForcedInclusions: type(uint8).max
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        assertEq(decoded.deadline, input.deadline, "max deadline");
        assertEq(decoded.blobReference.blobStartIndex, input.blobReference.blobStartIndex, "max start");
        assertEq(decoded.blobReference.numBlobs, input.blobReference.numBlobs, "max numBlobs");
        assertEq(decoded.blobReference.offset, input.blobReference.offset, "max offset");
        assertEq(decoded.numForcedInclusions, input.numForcedInclusions, "max forced");
    }
}
