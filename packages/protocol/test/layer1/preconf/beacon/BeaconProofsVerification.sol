// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibMerkleUtils.sol";
import "../BaseTest.sol";
import "../fixtures/BeaconProofs.sol";

/// @dev The beacon chain data used here is from slot 9000000 on Ethereum mainnet.
contract BeaconProofsVerification is BaseTest {
    function test_beaconProofsVerification_validatorInclusionInValidatorList() public {
        bytes32[8] memory validatorChunks = BeaconProofs.validatorChunks();

        bytes32 validatorHashTreeRoot = LibMerkleUtils.merkleize(validatorChunks);

        bytes32[] memory validatorProof = BeaconProofs.validatorProof();

        bytes32 validatorsRoot = BeaconProofs.validatorsRoot();
        uint256 validatorIndex = BeaconProofs.validatorIndex();

        assertTrue(
            LibMerkleUtils.verifyProof(
                validatorProof, validatorsRoot, validatorHashTreeRoot, validatorIndex
            )
        );
    }

    function test_beaconProofsVerification_validatorListInclusionInBeaconState() public {
        bytes32[] memory beaconStateProofForValidatorList =
            BeaconProofs.beaconStateProofForValidatorList();

        bytes32 validatorListRoot = BeaconProofs.validatorsRoot();
        bytes32 beaconStateRoot = BeaconProofs.beaconStateRoot();

        assertTrue(
            LibMerkleUtils.verifyProof(
                beaconStateProofForValidatorList, beaconStateRoot, validatorListRoot, 11
            )
        );
    }

    function test_beaconProofsVerification_beaconStateInclusionInBeaconBlock() public {
        bytes32[] memory beaconBlockProofForBeaconState =
            BeaconProofs.beaconBlockProofForBeaconState();

        bytes32 beaconStateRoot = BeaconProofs.beaconStateRoot();
        bytes32 beaconBlockRoot = BeaconProofs.beaconBlockRoot();

        assertTrue(
            LibMerkleUtils.verifyProof(
                beaconBlockProofForBeaconState, beaconBlockRoot, beaconStateRoot, 3
            )
        );
    }

    function test_beaconProofsVerification_proposerInclusionInBeaconBlock() public {
        bytes32[] memory beaconBlockProofForProposer = BeaconProofs.beaconBlockProofForProposer();

        uint256 validatorIndex = BeaconProofs.validatorIndex();
        bytes32 beaconBlockRoot = BeaconProofs.beaconBlockRoot();

        assertTrue(
            LibMerkleUtils.verifyProof(
                beaconBlockProofForProposer,
                beaconBlockRoot,
                LibMerkleUtils.toLittleEndian(validatorIndex),
                1
            )
        );
    }
}
