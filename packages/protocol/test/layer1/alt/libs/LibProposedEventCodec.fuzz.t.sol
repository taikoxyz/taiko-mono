// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/alt/libs/LibBlobs.sol";
import { LibProposedEventCodec } from "src/layer1/alt/libs/LibProposedEventCodec.sol";

/// @title LibProposedEventCodecFuzzTest
/// @notice Fuzz tests for LibProposedEventCodec to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventCodecFuzzTest is Test {
    /// @notice Fuzz test for proposal fields
    function testFuzz_encodeDecodeProposal(
        uint40 id,
        uint40 timestamp,
        uint40 endOfSubmissionWindowTimestamp,
        address proposer,
        bytes32 coreStateHash,
        bytes32 derivationHash,
        bytes32 parentProposalHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: id,
                timestamp: timestamp,
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: proposer,
                coreStateHash: coreStateHash,
                derivationHash: derivationHash,
                parentProposalHash: parentProposalHash
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.proposal.id, id);
        assertEq(decoded.proposal.timestamp, timestamp);
        assertEq(decoded.proposal.endOfSubmissionWindowTimestamp, endOfSubmissionWindowTimestamp);
        assertEq(decoded.proposal.proposer, proposer);
        assertEq(decoded.proposal.coreStateHash, coreStateHash);
        assertEq(decoded.proposal.derivationHash, derivationHash);
        assertEq(decoded.proposal.parentProposalHash, parentProposalHash);
    }

    /// @notice Fuzz test for derivation fields
    function testFuzz_encodeDecodeDerivation(
        uint40 originBlockNumber,
        uint8 basefeeSharingPctg,
        bytes32 originBlockHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: originBlockNumber,
                basefeeSharingPctg: basefeeSharingPctg,
                originBlockHash: originBlockHash,
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.derivation.originBlockNumber, originBlockNumber);
        assertEq(decoded.derivation.basefeeSharingPctg, basefeeSharingPctg);
        assertEq(decoded.derivation.originBlockHash, originBlockHash);
    }

    /// @notice Fuzz test for core state fields
    function testFuzz_encodeDecodeCoreState(
        uint40 proposalHead,
        uint40 proposalHeadContainerBlock,
        uint40 finalizationHead,
        uint40 synchronizationHead,
        bytes27 finalizationHeadTransitionHash,
        bytes32 aggregatedBondInstructionsHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                proposalHead: proposalHead,
                proposalHeadContainerBlock: proposalHeadContainerBlock,
                finalizationHead: finalizationHead,
                synchronizationHead: synchronizationHead,
                finalizationHeadTransitionHash: finalizationHeadTransitionHash,
                aggregatedBondInstructionsHash: aggregatedBondInstructionsHash
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.coreState.proposalHead, proposalHead);
        assertEq(decoded.coreState.proposalHeadContainerBlock, proposalHeadContainerBlock);
        assertEq(decoded.coreState.finalizationHead, finalizationHead);
        assertEq(decoded.coreState.synchronizationHead, synchronizationHead);
        assertEq(decoded.coreState.finalizationHeadTransitionHash, finalizationHeadTransitionHash);
        assertEq(decoded.coreState.aggregatedBondInstructionsHash, aggregatedBondInstructionsHash);
    }

    /// @notice Fuzz test for blob slice fields
    function testFuzz_encodeDecodeBlobSlice(
        uint24 offset,
        uint40 timestamp,
        bytes32 blobHash
    )
        public
        pure
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = blobHash;

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: offset, timestamp: timestamp
            })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.derivation.sources.length, 1);
        assertEq(decoded.derivation.sources[0].blobSlice.offset, offset);
        assertEq(decoded.derivation.sources[0].blobSlice.timestamp, timestamp);
        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes[0], blobHash);
    }

    /// @notice Fuzz test for variable sources count
    function testFuzz_encodeDecodeVariableSources(uint8 sourceCount) public pure {
        // Bound the inputs to reasonable values
        sourceCount = uint8(bound(sourceCount, 0, 10));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](sourceCount);
        for (uint256 i = 0; i < sourceCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encodePacked("blob", i));

            sources[i] = IInbox.DerivationSource({
                isForcedInclusion: i % 2 == 0,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(i * 100),
                    timestamp: uint40(1_700_000_000 + i)
                })
            });
        }

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.derivation.sources.length, sourceCount);
        for (uint256 i = 0; i < sourceCount; i++) {
            assertEq(decoded.derivation.sources[i].isForcedInclusion, i % 2 == 0);
            assertEq(decoded.derivation.sources[i].blobSlice.offset, uint24(i * 100));
            assertEq(decoded.derivation.sources[i].blobSlice.timestamp, uint40(1_700_000_000 + i));
        }
    }

    /// @notice Fuzz test for variable blob hashes count per source
    function testFuzz_encodeDecodeVariableBlobHashes(uint8 blobHashCount) public pure {
        // Bound the inputs to reasonable values
        blobHashCount = uint8(bound(blobHashCount, 1, 6));

        bytes32[] memory blobHashes = new bytes32[](blobHashCount);
        for (uint256 i = 0; i < blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encodePacked("blobHash", i));
        }

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: 100, timestamp: 1_700_000_000
            })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes.length, blobHashCount);
        for (uint256 i = 0; i < blobHashCount; i++) {
            assertEq(decoded.derivation.sources[0].blobSlice.blobHashes[i], blobHashes[i]);
        }
    }

    /// @notice Fuzz test to verify size calculation matches actual encoding
    function testFuzz_sizeCalculation(uint8 sourceCount, uint8 blobHashCount) public pure {
        // Bound the inputs
        sourceCount = uint8(bound(sourceCount, 0, 5));
        blobHashCount = uint8(bound(blobHashCount, 1, 4));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](sourceCount);
        for (uint256 i = 0; i < sourceCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](blobHashCount);
            for (uint256 j = 0; j < blobHashCount; j++) {
                blobHashes[j] = keccak256(abi.encodePacked("blob", i, j));
            }

            sources[i] = IInbox.DerivationSource({
                isForcedInclusion: i % 2 == 0,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(i * 100),
                    timestamp: uint40(1_700_000_000 + i)
                })
            });
        }

        uint256 calculatedSize = LibProposedEventCodec.calculateProposedEventSize(sources);

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);

        assertEq(encoded.length, calculatedSize, "Calculated size should match actual encoding");
    }

    /// @notice Fuzz test for full payload with all fields randomized
    function testFuzz_fullPayload(
        uint40 proposalId,
        address proposer,
        uint40 originBlockNumber,
        uint8 basefeeSharingPctg,
        uint8 sourceCount,
        bool isForcedInclusion
    )
        public
        pure
    {
        // Bound proposalId to avoid underflow in coreState calculations
        proposalId = uint40(bound(proposalId, 11, type(uint40).max));
        sourceCount = uint8(bound(sourceCount, 0, 5));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](sourceCount);
        for (uint256 i = 0; i < sourceCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encodePacked("blob", i));

            sources[i] = IInbox.DerivationSource({
                isForcedInclusion: isForcedInclusion,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(i * 100),
                    timestamp: uint40(1_700_000_000 + i)
                })
            });
        }

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: proposalId,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: proposer,
                coreStateHash: keccak256(abi.encodePacked("coreState", proposalId)),
                derivationHash: keccak256(abi.encodePacked("derivation", proposalId)),
                parentProposalHash: keccak256(abi.encodePacked("parentProposal", proposalId))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: originBlockNumber,
                basefeeSharingPctg: basefeeSharingPctg,
                originBlockHash: keccak256(abi.encodePacked("originBlock", originBlockNumber)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: proposalId,
                proposalHeadContainerBlock: proposalId - 1,
                finalizationHead: proposalId > 5 ? proposalId - 5 : 0,
                synchronizationHead: proposalId > 10 ? proposalId - 10 : 0,
                finalizationHeadTransitionHash: bytes27(
                    keccak256(abi.encodePacked("finHash", proposalId))
                ),
                aggregatedBondInstructionsHash: keccak256(abi.encodePacked("bonds", proposalId))
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        // Verify key fields
        assertEq(decoded.proposal.id, proposalId);
        assertEq(decoded.proposal.proposer, proposer);
        assertEq(decoded.derivation.originBlockNumber, originBlockNumber);
        assertEq(decoded.derivation.basefeeSharingPctg, basefeeSharingPctg);
        assertEq(decoded.derivation.sources.length, sourceCount);
    }
}
