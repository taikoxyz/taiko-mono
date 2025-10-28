// SPDX-License-Identifier: MIT

// Referenced from: https://ethresear.ch/t/slashing-proofoor-on-chain-slashed-validator-proofs/19421
pragma solidity ^0.8.24;

import { BLSUtils } from "@eth-fabric/urc/lib/BLSUtils.sol";
import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title LibEIP4788
/// @custom:security-contact security@taiko.xyz
library LibEIP4788 {
    /// @dev Proof of inclusion of the first validator chunk in the beacon
    /// state.
    struct ValidatorChunkProof {
        // Index of the validator in the validator list
        uint256 validatorIndex;
        // This is intended to be the chunk at the 0-th index.
        // This is the hash tree root of the validator's public key
        bytes32 validatorChunk;
        // Merkle root of the merkle-ized validator chunks
        bytes32 validatorRoot;
        // Merkle root of the merkle-ized validator list
        bytes32 validatorsListRoot;
        // Merkle root of the merkle-ized beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of the chunk in the validator
        bytes32[] proofOfInclusionInValidator;
        // Proof of incluson of the validator in the validator list
        bytes32[] proofOfInclusionInValidatorList;
        // Proof of incluson of the validator list in the beacon state
        bytes32[] proofOfInclusionInBeaconState;
    }

    /// @dev Proof of inclusion of a certain validator index at a certain proposer
    /// lookahead index
    struct ProposerLookaheadProof {
        // The lookahead index whose value we are trying to prove
        uint256 proposerLookaheadIndex;
        // The proposer lookahead chunk containing the expected validator index
        bytes32 proposerLookaheadChunk;
        // Merkle root of the merkle-ized proposer lookahead
        bytes32 proposerLookaheadRoot;
        // Merkle root of the merkle-ized beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of validator index in proposer lookahead
        bytes32[] proofOfInclusionInProposerLookahead;
        // Proof of incluson of the proposer lookahead in the beacon state
        bytes32[] proofOfInclusionInBeaconState;
    }

    /// @dev Proof of inclusion of the beacon state root in the beacon block header
    struct BeaconStateProof {
        // Merkle root of the merkle-ized beacon state
        bytes32 beaconStateRoot;
        // Merkle root of the beacon block
        // Note: This must be same as the root made available via EIP-4788
        bytes32 beaconBlockHeaderRoot;
        // Proof of incluson of the beacon state root in a certain beacon block
        bytes32[] proofOfInclusionInBeaconBlock;
    }

    struct BeaconProofs {
        ValidatorChunkProof validatorChunkProof;
        ProposerLookaheadProof proposerLookaheadProof;
        BeaconStateProof beaconStateProof;
    }

    error ValidatorChunkProof_InvalidValidatorChunk();
    error ValidatorIndexMismatch();
    error BeaconStateRootMismatch();
    error ValidatorChunkProof_ProofOfInclusionInValidatorFailed();
    error ValidatorChunkProof_ProofOfInclusionInValidatorListFailed();
    error ValidatorChunkProof_ProofOfInclusionInBeaconStateFailed();
    error ProposerLookaheadProof_ProofOfInclusionInProposerLookaheadFailed();
    error ProposerLookaheadProof_ProofOfInclusionInBeaconStateFailed();
    error BeaconStateProof_ProofOfInclusionInBeaconBlockFailed();

    function verifyBeaconProofs(
        BLS.G1Point calldata _validatorPubKey,
        BeaconProofs calldata _beaconProofs
    )
        internal
        view
    {
        BLS.Fp memory compressedValidatorPubKeyFp = BLSUtils.compress(_validatorPubKey);

        // Shifts the 16-byte 0-padding to the end
        bytes32 x = compressedValidatorPubKeyFp.a << 128 | compressedValidatorPubKeyFp.b >> 128;
        bytes32 y = compressedValidatorPubKeyFp.b << 128;

        // Verify that the `ValidatorChunkProof.validatorChunk` is the validator public key's
        // hash tree root
        bytes32 pubKeyHashTreeRoot = sha256(abi.encodePacked(x, y));
        require(
            pubKeyHashTreeRoot == _beaconProofs.validatorChunkProof.validatorChunk,
            ValidatorChunkProof_InvalidValidatorChunk()
        );

        // Verify that the beacon state root matches in all proofs
        bytes32 beaconStateRoot_ = _beaconProofs.validatorChunkProof.beaconStateRoot;
        require(
            beaconStateRoot_ == _beaconProofs.proposerLookaheadProof.beaconStateRoot
                && beaconStateRoot_ == _beaconProofs.beaconStateProof.beaconStateRoot,
            BeaconStateRootMismatch()
        );

        // Verify that the validator chunk is a part of the validator
        require(
            _verifyProof(
                _beaconProofs.validatorChunkProof.proofOfInclusionInValidator,
                _beaconProofs.validatorChunkProof.validatorRoot,
                _beaconProofs.validatorChunkProof.validatorChunk,
                0 // chunk at 0-th index
            ),
            ValidatorChunkProof_ProofOfInclusionInValidatorFailed()
        );

        // Verify that the validator root is a part of the validator list
        require(
            _verifyProof(
                _beaconProofs.validatorChunkProof.proofOfInclusionInValidatorList,
                _beaconProofs.validatorChunkProof.validatorsListRoot,
                _beaconProofs.validatorChunkProof.validatorRoot,
                _beaconProofs.validatorChunkProof.validatorIndex
            ),
            ValidatorChunkProof_ProofOfInclusionInValidatorListFailed()
        );

        // Verify that the validators list is a part of the beacon state
        require(
            _verifyProof(
                _beaconProofs.validatorChunkProof.proofOfInclusionInBeaconState,
                _beaconProofs.validatorChunkProof.beaconStateRoot,
                _beaconProofs.validatorChunkProof.validatorsListRoot,
                11 // validators index in beacon state
            ),
            ValidatorChunkProof_ProofOfInclusionInBeaconStateFailed()
        );

        // Chunk index and the index of the segment within the chunk that is expected to have the validator
        // index.
        // Each chunk has 4 64-bit segments, each containing one validator index.
        uint256 proposerLookaheadChunkIndex =
            _beaconProofs.proposerLookaheadProof.proposerLookaheadIndex / 4;
        uint256 proposerLookaheadChunkSegmentIndex =
            _beaconProofs.proposerLookaheadProof.proposerLookaheadIndex % 4;

        // Extract the u64 little-endian encoded validator index and make it
        // u256 little-endian
        bytes32 expectedValidatorIndex = (
            (
                _beaconProofs.proposerLookaheadProof.proposerLookaheadChunk
                    << (proposerLookaheadChunkSegmentIndex * 64)
            ) >> 192
        ) << 192;

        // Verify that the validator index in the validator chunk proof matches the one in the lookahead
        // proof
        require(
            _toLittleEndian(_beaconProofs.validatorChunkProof.validatorIndex)
                == expectedValidatorIndex,
            ValidatorIndexMismatch()
        );

        // Verify that the chunk is a part of the proposer lookahead
        require(
            _verifyProof(
                _beaconProofs.proposerLookaheadProof.proofOfInclusionInProposerLookahead,
                _beaconProofs.proposerLookaheadProof.proposerLookaheadRoot,
                _beaconProofs.proposerLookaheadProof.proposerLookaheadChunk,
                proposerLookaheadChunkIndex
            ),
            ProposerLookaheadProof_ProofOfInclusionInProposerLookaheadFailed()
        );

        // Verify that the proposer lookahead is a part of the beacon state
        require(
            _verifyProof(
                _beaconProofs.proposerLookaheadProof.proofOfInclusionInBeaconState,
                _beaconProofs.proposerLookaheadProof.beaconStateRoot,
                _beaconProofs.proposerLookaheadProof.proposerLookaheadRoot,
                37 // proposer_lookahead index in beacon state
            ),
            ProposerLookaheadProof_ProofOfInclusionInBeaconStateFailed()
        );

        // Verify that the beacon state is a part of the beacon block
        require(
            _verifyProof(
                _beaconProofs.beaconStateProof.proofOfInclusionInBeaconBlock,
                _beaconProofs.beaconStateProof.beaconBlockHeaderRoot,
                _beaconProofs.beaconStateProof.beaconStateRoot,
                3 // state_root index in beacon block
            ),
            BeaconStateProof_ProofOfInclusionInBeaconBlockFailed()
        );
    }

    function _verifyProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf,
        uint256 leafIndex
    )
        internal
        view
        returns (bool)
    {
        bytes32 h = leaf;
        uint256 index = leafIndex;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            // if index is even -> sha256(h, proofElement)
            // else -> sha256(proofElement, h)
            assembly {
                let ptr := mload(0x40)

                switch and(index, 1)
                case 0 {
                    mstore(ptr, h)
                    mstore(add(ptr, 0x20), proofElement)
                }
                default {
                    mstore(ptr, proofElement)
                    mstore(add(ptr, 0x20), h)
                }

                // sha256 precompile
                if iszero(staticcall(gas(), 0x02, ptr, 0x40, ptr, 0x20)) { revert(0, 0) }
                h := mload(ptr)

                // Reclaim memory
                mstore(0x40, ptr)
            }

            index = index / 2;
        }

        return h == root;
    }

    function _toLittleEndian(uint256 n) internal pure returns (bytes32) {
        uint256 v = n;
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
            | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
            | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
            | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
            | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        v = (v >> 128) | (v << 128);
        return bytes32(v);
    }
}
