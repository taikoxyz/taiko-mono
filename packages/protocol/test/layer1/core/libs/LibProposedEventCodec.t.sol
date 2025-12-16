// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposedEventCodec } from "src/layer1/core/libs/LibProposedEventCodec.sol";

contract LibProposedEventCodecHarness {
    function size(IInbox.DerivationSource[] memory _sources) external pure returns (uint256) {
        return LibProposedEventCodec.calculateProposedEventSize(_sources);
    }
}

contract LibProposedEventCodecTest is Test {
    LibProposedEventCodecHarness private harness = new LibProposedEventCodecHarness();

    function test_encode_decode_singleSource() public view {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _hashes(bytes32(uint256(1)), bytes32(uint256(2))),
                offset: 21,
                timestamp: 123
            })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 5,
                timestamp: 111,
                endOfSubmissionWindowTimestamp: 0,
                proposer: address(0x1234),
                parentProposalHash: bytes32(uint256(9)),
                originBlockNumber: 99,
                originBlockHash: bytes32(uint256(7)),
                basefeeSharingPctg: 3,
                sources: sources
            })
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        assertEq(encoded.length, harness.size(sources), "size mismatch");

        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);
        _assertEqual(payload, decoded);
    }

    function test_encode_decode_mixedSources() public pure {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _hashes(bytes32(uint256(111))), offset: 0, timestamp: 55
            })
        });
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _hashes(
                    bytes32(uint256(211)), bytes32(uint256(212)), bytes32(uint256(213))
                ),
                offset: 88,
                timestamp: 66
            })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 77,
                timestamp: 200,
                endOfSubmissionWindowTimestamp: 300,
                proposer: address(0xBEEF),
                parentProposalHash: bytes32(uint256(13)),
                originBlockNumber: 150,
                originBlockHash: bytes32(uint256(151)),
                basefeeSharingPctg: 9,
                sources: sources
            })
        });

        IInbox.ProposedEventPayload memory decoded =
            LibProposedEventCodec.decode(LibProposedEventCodec.encode(payload));

        assertEq(decoded.proposal.sources.length, 2, "sources length");
        assertTrue(decoded.proposal.sources[0].isForcedInclusion, "forced flag");
        assertEq(decoded.proposal.sources[1].blobSlice.blobHashes.length, 3, "blob hashes length");
        assertEq(decoded.proposal.sources[1].blobSlice.offset, 88, "offset");
        assertEq(decoded.proposal.sources[1].blobSlice.timestamp, 66, "timestamp");
        _assertEqual(payload, decoded);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _hashes(bytes32 _h1) private pure returns (bytes32[] memory arr_) {
        arr_ = new bytes32[](1);
        arr_[0] = _h1;
    }

    function _hashes(bytes32 _h1, bytes32 _h2) private pure returns (bytes32[] memory arr_) {
        arr_ = new bytes32[](2);
        arr_[0] = _h1;
        arr_[1] = _h2;
    }

    function _hashes(
        bytes32 _h1,
        bytes32 _h2,
        bytes32 _h3
    )
        private
        pure
        returns (bytes32[] memory arr_)
    {
        arr_ = new bytes32[](3);
        arr_[0] = _h1;
        arr_[1] = _h2;
        arr_[2] = _h3;
    }

    function _assertEqual(
        IInbox.ProposedEventPayload memory _expected,
        IInbox.ProposedEventPayload memory _actual
    )
        private
        pure
    {
        assertEq(_actual.proposal.id, _expected.proposal.id, "proposal id");
        assertEq(_actual.proposal.timestamp, _expected.proposal.timestamp, "proposal timestamp");
        assertEq(
            _actual.proposal.endOfSubmissionWindowTimestamp,
            _expected.proposal.endOfSubmissionWindowTimestamp,
            "proposal submission window"
        );
        assertEq(_actual.proposal.proposer, _expected.proposal.proposer, "proposal proposer");
        assertEq(
            _actual.proposal.parentProposalHash,
            _expected.proposal.parentProposalHash,
            "parent hash"
        );

        assertEq(
            _actual.proposal.originBlockNumber, _expected.proposal.originBlockNumber, "origin block"
        );
        assertEq(
            _actual.proposal.originBlockHash, _expected.proposal.originBlockHash, "origin hash"
        );
        assertEq(
            _actual.proposal.basefeeSharingPctg, _expected.proposal.basefeeSharingPctg, "basefee"
        );
        assertEq(
            _actual.proposal.sources.length, _expected.proposal.sources.length, "sources length"
        );

        for (uint256 i; i < _actual.proposal.sources.length; ++i) {
            assertEq(
                _actual.proposal.sources[i].isForcedInclusion,
                _expected.proposal.sources[i].isForcedInclusion,
                "forced flag"
            );
            assertEq(
                _actual.proposal.sources[i].blobSlice.blobHashes,
                _expected.proposal.sources[i].blobSlice.blobHashes,
                "blob hashes"
            );
            assertEq(
                _actual.proposal.sources[i].blobSlice.offset,
                _expected.proposal.sources[i].blobSlice.offset,
                "offset"
            );
            assertEq(
                _actual.proposal.sources[i].blobSlice.timestamp,
                _expected.proposal.sources[i].blobSlice.timestamp,
                "timestamp"
            );
        }
    }
}
