// SPDX-License-Identifier: MIT

// Referenced from: https://ethresear.ch/t/slashing-proofoor-on-chain-slashed-validator-proofs/19421
pragma solidity ^0.8.24;

import "./LibBeaconMerkleUtils.sol";
import "@eth-fabric/urc/lib/BLSUtils.sol";
import "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title LibEIP4788
/// @custom:security-contact security@taiko.xyz
library LibEIP4788 {
    struct InclusionProof {
        // `Chunks` of the SSZ encoded validator
        bytes32[8] validator;
        // Index of the validator in the beacon state validator list
        uint256 validatorIndex;
        // Proof of inclusion of validator in beacon state validator list
        bytes32[] validatorProof;
        // Root of the validator list in the beacon state
        bytes32 validatorsRoot;
        // Proof of inclusion of the root of validators list in the beacon state
        bytes32[] validatorsRootProof;
        // Index of the validator in the beacon state proposer lookahead
        uint256 proposerLookaheadIndex;
        // Proof of inclusion of validator index in the proposer lookahead
        bytes32[] validatorIndexProof;
        // Root of the proposer lookahead in the beacon state
        bytes32 proposerLookaheadRoot;
        // Proof of inclusion of the root of proposer lookahead in the beacon state
        bytes32[] proposerLookaheadRootProof;
        // Root of the beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of beacon state in the beacon block
        bytes32[] beaconStateRootProof;
    }

    error InvalidValidatorPubKey();
    error ValidatorProofVerificationFailed();
    error ValidatorsRootProofVerificationFailed();
    error InvalidProposerLookaheadIndex();
    error ValidatorIndexProofVerificationFailed();
    error BeaconStateProofVerificationFailed();

    function verifyValidator(
        uint256 _expectedProposerLookaheadIndex,
        BLS.G1Point memory _validatorPubKey,
        bytes32 _beaconBlockRoot,
        InclusionProof memory _inclusionProof
    )
        internal
        pure
    {
        BLS.Fp memory compressedValidatorPubKeyFp = BLSUtils.compress(_validatorPubKey);

        // Shifts the 16-byte 0-padding to the end
        bytes32 x = compressedValidatorPubKeyFp.a << 128 | compressedValidatorPubKeyFp.b >> 128;
        bytes32 y = compressedValidatorPubKeyFp.b << 128;

        // Verify: Validator chunks contains the validator public key
        bytes32 pubKeyHashTreeRoot = sha256(abi.encodePacked(x, y));
        require(pubKeyHashTreeRoot == _inclusionProof.validator[0], InvalidValidatorPubKey());

        // Verify: Validator is a part of the validator list in the beacon state
        bytes32 validatorHashTreeRoot = LibBeaconMerkleUtils.merkleize(_inclusionProof.validator);
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorProof,
                _inclusionProof.validatorsRoot,
                validatorHashTreeRoot,
                _inclusionProof.validatorIndex
            ),
            ValidatorProofVerificationFailed()
        );

        // Verify: Validator list is a part of the beacon state
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorsRootProof,
                _inclusionProof.beaconStateRoot,
                _inclusionProof.validatorsRoot,
                11
            ),
            ValidatorsRootProofVerificationFailed()
        );

        // Verify: Validator index is a part of the proposer lookahead at the expected index
        require(
            _inclusionProof.proposerLookaheadIndex == _expectedProposerLookaheadIndex,
            InvalidProposerLookaheadIndex()
        );
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorIndexProof,
                _inclusionProof.proposerLookaheadRoot,
                LibBeaconMerkleUtils.toLittleEndian(_inclusionProof.validatorIndex),
                _inclusionProof.proposerLookaheadIndex
            ),
            ValidatorIndexProofVerificationFailed()
        );

        // Verify: Beacon state is a part of the beacon block
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.beaconStateRootProof,
                _beaconBlockRoot,
                _inclusionProof.beaconStateRoot,
                3
            ),
            BeaconStateProofVerificationFailed()
        );
    }
}
