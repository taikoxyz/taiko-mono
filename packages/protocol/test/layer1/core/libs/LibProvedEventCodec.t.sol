// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/core/libs/LibProvedEventCodec.sol";

contract LibProvedEventCodecTest is Test {
    function test_encode_decode_basic() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: 5,
            lastProposalId: 10,
            actualProver: address(0xAAAA),
            checkpointSynced: false
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.firstProposalId, payload.firstProposalId, "firstProposalId");
        assertEq(decoded.lastProposalId, payload.lastProposalId, "lastProposalId");
        assertEq(decoded.actualProver, payload.actualProver, "actualProver");
        assertEq(decoded.checkpointSynced, payload.checkpointSynced, "checkpointSynced");
    }

    function test_encode_decode_withCheckpointSynced() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: 100,
            lastProposalId: 200,
            actualProver: address(0xBBBB),
            checkpointSynced: true
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.firstProposalId, payload.firstProposalId, "firstProposalId");
        assertEq(decoded.lastProposalId, payload.lastProposalId, "lastProposalId");
        assertEq(decoded.actualProver, payload.actualProver, "actualProver");
        assertTrue(decoded.checkpointSynced, "checkpointSynced should be true");
    }

    function test_encode_deterministic() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: 42,
            lastProposalId: 50,
            actualProver: address(0xDDDD),
            checkpointSynced: false
        });

        bytes memory encoded1 = LibProvedEventCodec.encode(payload);
        bytes memory encoded2 = LibProvedEventCodec.encode(payload);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }

    function test_encoded_size() public pure {
        // Test that encoded size matches expected: 33 bytes
        // firstProposalId (6) + lastProposalId (6) + actualProver (20) + checkpointSynced (1) = 33
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: 1,
            lastProposalId: 2,
            actualProver: address(0xAAAA),
            checkpointSynced: false
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);

        assertEq(encoded.length, 33, "encoded size should be 33 bytes");
    }

    function test_encode_decode_maxValues() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: type(uint48).max,
            lastProposalId: type(uint48).max,
            actualProver: address(type(uint160).max),
            checkpointSynced: true
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.firstProposalId, type(uint48).max, "firstProposalId max");
        assertEq(decoded.lastProposalId, type(uint48).max, "lastProposalId max");
        assertEq(decoded.actualProver, address(type(uint160).max), "actualProver max");
        assertTrue(decoded.checkpointSynced, "checkpointSynced");
    }

    function test_encode_decode_zeroValues() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            firstProposalId: 0, lastProposalId: 0, actualProver: address(0), checkpointSynced: false
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.firstProposalId, 0, "firstProposalId zero");
        assertEq(decoded.lastProposalId, 0, "lastProposalId zero");
        assertEq(decoded.actualProver, address(0), "actualProver zero");
        assertFalse(decoded.checkpointSynced, "checkpointSynced false");
    }
}
