// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";
import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { LibEIP4788 } from "src/layer1/preconf/libs/LibEIP4788.sol";

/// @dev This test utilises actual data from Fusaka devnet 3, slot 688808.
/// @dev Proofs are for validator at index 328 in the validator list and
/// at index 30 within the proposer lookahead
contract TestLibEIP4788 is Test {
    Wrapper libEIP4788;

    function setUp() external {
        libEIP4788 = new Wrapper();
    }

    // Success Tests
    // ---------------------------------------------------------------------------

    function test_verifyBeaconProofs_succeeds() external view {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();

        // This should not revert when called with valid data
        uint256 g = gasleft();
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
        console2.log("Proof verification gas: ", g - gasleft());
    }

    // Revert Tests
    // ---------------------------------------------------------------------------

    function test_verifyBeaconProofs_revertsWhenInvalidValidatorChunk_case1() external {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the validator chunk to make it invalid
        beaconProofs.validatorChunkProof.validatorChunk =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(LibEIP4788.ValidatorChunkProof_InvalidValidatorChunk.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenInvalidValidatorChunk_case2() external {
        // Different pubkey from the one within the chunk
        BLS.G1Point memory validatorPubKey = BLS.G1Point({
            x_a: 0x000000000000000000000000000000000cff05e07b315ca1f8fe7eeddfed0151,
            x_b: 0xfce13b6993e4a2f54c1fc6b10324fcbe9d829580c58d22253fc1aeba8e577b62,
            y_a: 0x000000000000000000000000000000000d447cb039b5888d1096245783b6f29f,
            y_b: 0xff850e666a87a7bd86c800fb56a48f68c6b36b311adceec192200538ef781a3a
        });

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();

        vm.expectRevert(LibEIP4788.ValidatorChunkProof_InvalidValidatorChunk.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenBeaconStateRootMismatch_case1() external {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the beacon state root in validator chunk proof
        beaconProofs.validatorChunkProof.beaconStateRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(LibEIP4788.BeaconStateRootMismatch.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenBeaconStateRootMismatch_case2() external {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the beacon state root in proposer lookahead proof
        beaconProofs.proposerLookaheadProof.beaconStateRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(LibEIP4788.BeaconStateRootMismatch.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenBeaconStateRootMismatch_case3() external {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the beacon state root in beacon state proof
        beaconProofs.beaconStateProof.beaconStateRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(LibEIP4788.BeaconStateRootMismatch.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenValidatorChunkProofOfInclusionInValidatorFailed()
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the validator root to make the proof invalid
        beaconProofs.validatorChunkProof.validatorRoot =
            0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(LibEIP4788.ValidatorChunkProof_ProofOfInclusionInValidatorFailed.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenValidatorChunkProofOfInclusionInValidatorListFailed(
    )
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the validators list root to make the proof invalid
        beaconProofs.validatorChunkProof.validatorsListRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(
            LibEIP4788.ValidatorChunkProof_ProofOfInclusionInValidatorListFailed.selector
        );
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenValidatorChunkProofOfInclusionInBeaconStateFailed()
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the beacon state root to make the proof invalid
        beaconProofs.validatorChunkProof.proofOfInclusionInBeaconState[0] =
            0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(LibEIP4788.ValidatorChunkProof_ProofOfInclusionInBeaconStateFailed.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenValidatorIndexMismatch() external {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the validator in the proposer lookahead chunk to make it not match the
        // validator index
        beaconProofs.proposerLookaheadProof.proposerLookaheadChunk =
            0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(LibEIP4788.ValidatorIndexMismatch.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenProposerLookaheadProofOfInclusionInProposerLookaheadFailed(
    )
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the proposer lookahead root to make the proof invalid
        beaconProofs.proposerLookaheadProof.proposerLookaheadRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(
            LibEIP4788.ProposerLookaheadProof_ProofOfInclusionInProposerLookaheadFailed.selector
        );
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenProposerLookaheadProofOfInclusionInBeaconStateFailed(
    )
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the proof to make it invalid
        beaconProofs.proposerLookaheadProof.proofOfInclusionInBeaconState[0] =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(
            LibEIP4788.ProposerLookaheadProof_ProofOfInclusionInBeaconStateFailed.selector
        );
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    function test_verifyBeaconProofs_revertsWhenBeaconStateProofOfInclusionInBeaconBlockFailed()
        external
    {
        BLS.G1Point memory validatorPubKey = _getValidatorPubKey();

        LibEIP4788.BeaconProofs memory beaconProofs = _getBeaconProofs();
        // Modify the beacon block header root to make the proof invalid
        beaconProofs.beaconStateProof.beaconBlockHeaderRoot =
            0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.expectRevert(LibEIP4788.BeaconStateProof_ProofOfInclusionInBeaconBlockFailed.selector);
        libEIP4788.verifyBeaconProofs(validatorPubKey, beaconProofs);
    }

    // Helpers
    // ---------------------------------------------------------------------------

    function _getProposerLookaheadProof()
        internal
        pure
        returns (LibEIP4788.ProposerLookaheadProof memory)
    {
        bytes32[] memory proofOfInclusionInProposerLookahead = new bytes32[](4);
        proofOfInclusionInProposerLookahead[0] =
            0x9801000000000000d00100000000000053030000000000001500000000000000;
        proofOfInclusionInProposerLookahead[1] =
            0x4b8e1f35bdc34b384689f06eef1c93e67a04c07d222cc08211f771189f1d0aa3;
        proofOfInclusionInProposerLookahead[2] =
            0x8315af6b180d18b5362fa3b886107a18a8f5a2809a158e56ce50d83b1ce49269;
        proofOfInclusionInProposerLookahead[3] =
            0x3f9e004a6a4143f53d48576b255ebd84ffb018e55acd2f5c844f4f817e6420f7;

        bytes32[] memory proofOfInclusionInBeaconState = new bytes32[](6);
        proofOfInclusionInBeaconState[0] =
            0xe7990d74a7bd8d59a8036fbdde3196e3218fdd347d520144a97a9a268202ec4b;
        proofOfInclusionInBeaconState[1] =
            0xf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b;
        proofOfInclusionInBeaconState[2] =
            0x3956457f5c94b391ac4977c996bbaf2f709bd14455276721320332c51288ad55;
        proofOfInclusionInBeaconState[3] =
            0xc78009fdf07fc56a11f122370658a353aaa542ed63e44c4bc15ff4cd105ab33c;
        proofOfInclusionInBeaconState[4] =
            0x536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c;
        proofOfInclusionInBeaconState[5] =
            0xf38c4122a0b5085fa3c3cda90d223dcd443ba8ce464c5c1a6b4fe2d305d9f630;

        return LibEIP4788.ProposerLookaheadProof({
            proposerLookaheadIndex: 30,
            proposerLookaheadChunk: 0xb000000000000000600000000000000048010000000000006000000000000000,
            proposerLookaheadRoot: 0xb05c373686132681dcd8f582f33757764a71611fa7af717e2df5a69492b28c85,
            beaconStateRoot: 0xf9124d8486400eed8d01cc4117b1e19a8a1b3f6caeb2150d5a2260cc5be89d93,
            proofOfInclusionInProposerLookahead: proofOfInclusionInProposerLookahead,
            proofOfInclusionInBeaconState: proofOfInclusionInBeaconState
        });
    }

    function _getValidatorChunkProof()
        internal
        pure
        returns (LibEIP4788.ValidatorChunkProof memory)
    {
        bytes32[] memory proofOfInclusionInValidator = new bytes32[](3);
        proofOfInclusionInValidator[0] =
            0x020000000000000000000000f97e180c050e5ab072211ad2c213eb5aee4df134;
        proofOfInclusionInValidator[1] =
            0x8f8b0706ec2c88ebc070be66dbb2164bdb8f2918d0a7aef69534d65848622501;
        proofOfInclusionInValidator[2] =
            0xbcd42b1f092780448fb0131cd25a24c9d25e4b3b610774ae9aa8d3e437e811fe;

        bytes32[] memory proofOfInclusionInValidatorList = new bytes32[](41);
        proofOfInclusionInValidatorList[0] =
            0xbafecb9609900295d0984320ccfcf40753d524541f1572e536230733223b3205;
        proofOfInclusionInValidatorList[1] =
            0xc59614bc43f0b39f940d332240696ae9818097f213d075c5c58068581947fb1b;
        proofOfInclusionInValidatorList[2] =
            0xa4c374cd7d2500167d39b2b64ea5121c7ad90f8e9f5b97299bbe6d4b1034dd38;
        proofOfInclusionInValidatorList[3] =
            0x7d8fc7296625ebafc07c64377f07fa7555a619103858aaf2405611eba2b9413f;
        proofOfInclusionInValidatorList[4] =
            0x267e738dde6e930a96d51fd05bd91bf4d023bb39fb0eb94f09d958dc2265698e;
        proofOfInclusionInValidatorList[5] =
            0x3aa8b38e29163e49f2cf16d59ccc8b3542148f831ca4daf155acd395ffe97f26;
        proofOfInclusionInValidatorList[6] =
            0xe119dd58393eac0baa2796e01e3ea2ea5903566d42e695811fe3a620ce4e110c;
        proofOfInclusionInValidatorList[7] =
            0x57ad8867282f25d9da941f2f795a0bf6c8a3723209cea98d81cd6ab4cfad8d4e;
        proofOfInclusionInValidatorList[8] =
            0x518c6c26a7b41f0c3147588b1cbebdc95667b8cd4e86e246db88186ad5c68e50;
        proofOfInclusionInValidatorList[9] =
            0x1c54d5a24f2873ac7fe73f62c2e063a237813599a8c554640147857ca70867af;
        proofOfInclusionInValidatorList[10] =
            0xffff0ad7e659772f9534c195c815efc4014ef1e1daed4404c06385d11192e92b;
        proofOfInclusionInValidatorList[11] =
            0x6cf04127db05441cd833107a52be852868890e4317e6a02ab47683aa75964220;
        proofOfInclusionInValidatorList[12] =
            0xb7d05f875f140027ef5118a2247bbb84ce8f2f0f1123623085daf7960c329f5f;
        proofOfInclusionInValidatorList[13] =
            0xdf6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85e;
        proofOfInclusionInValidatorList[14] =
            0xb58d900f5e182e3c50ef74969ea16c7726c549757cc23523c369587da7293784;
        proofOfInclusionInValidatorList[15] =
            0xd49a7502ffcfb0340b1d7885688500ca308161a7f96b62df9d083b71fcc8f2bb;
        proofOfInclusionInValidatorList[16] =
            0x8fe6b1689256c0d385f42f5bbe2027a22c1996e110ba97c171d3e5948de92beb;
        proofOfInclusionInValidatorList[17] =
            0x8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab;
        proofOfInclusionInValidatorList[18] =
            0x95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4;
        proofOfInclusionInValidatorList[19] =
            0xf893e908917775b62bff23294dbbe3a1cd8e6cc1c35b4801887b646a6f81f17f;
        proofOfInclusionInValidatorList[20] =
            0xcddba7b592e3133393c16194fac7431abf2f5485ed711db282183c819e08ebaa;
        proofOfInclusionInValidatorList[21] =
            0x8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9c;
        proofOfInclusionInValidatorList[22] =
            0xfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167;
        proofOfInclusionInValidatorList[23] =
            0xe71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7;
        proofOfInclusionInValidatorList[24] =
            0x31206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc0;
        proofOfInclusionInValidatorList[25] =
            0x21352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544;
        proofOfInclusionInValidatorList[26] =
            0x619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a46765;
        proofOfInclusionInValidatorList[27] =
            0x7cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4;
        proofOfInclusionInValidatorList[28] =
            0x848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe1;
        proofOfInclusionInValidatorList[29] =
            0x8869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636;
        proofOfInclusionInValidatorList[30] =
            0xb5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c;
        proofOfInclusionInValidatorList[31] =
            0x985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7;
        proofOfInclusionInValidatorList[32] =
            0xc6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff;
        proofOfInclusionInValidatorList[33] =
            0x1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc5;
        proofOfInclusionInValidatorList[34] =
            0x2f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d;
        proofOfInclusionInValidatorList[35] =
            0x328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362c;
        proofOfInclusionInValidatorList[36] =
            0xbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c327;
        proofOfInclusionInValidatorList[37] =
            0x55d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a74;
        proofOfInclusionInValidatorList[38] =
            0xf7210d4f8e7e1039790e7bf4efa207555a10a6db1dd4b95da313aaa88b88fe76;
        proofOfInclusionInValidatorList[39] =
            0xad21b516cbc645ffe34ab5de1c8aef8cd4e7f8d2b51e8e1456adc7563cda206f;
        proofOfInclusionInValidatorList[40] =
            0xa203000000000000000000000000000000000000000000000000000000000000;

        bytes32[] memory proofOfInclusionInBeaconState = new bytes32[](6);
        proofOfInclusionInBeaconState[0] =
            0x0000000000000000000000000000000000000000000000000000000000000000;
        proofOfInclusionInBeaconState[1] =
            0x698b03ed811b9d4b1af906b8c4279197bd25adb08ac672d2046a04a408f25eac;
        proofOfInclusionInBeaconState[2] =
            0x1082b93b4216519d9c6452110cce9750f68529547bb028ee5363b3fd02a30207;
        proofOfInclusionInBeaconState[3] =
            0x6ec216b2b8018ce7bf2eca08887266783055d4768adba7a00bded5b5354fac65;
        proofOfInclusionInBeaconState[4] =
            0xb48bb82c21476b407d95a1215f7c5ecd25a3bccce5ffeba43eeef668421e141a;
        proofOfInclusionInBeaconState[5] =
            0xe9155bfcb94aa0b1dec3fc203ed473b003fbc2787d35933e9905f0683a5b0caa;

        return LibEIP4788.ValidatorChunkProof({
            validatorIndex: 328,
            validatorChunk: 0x429c4f8689638e1e8d755ddea0457596584b23202a1eddcf99ed01a66949fa41,
            validatorRoot: 0x9f4fcaf6f9a12b31da64a09ae4a4b13310fc36eced8be1ebf89ba1ad5be9912d,
            validatorsListRoot: 0x01f5d88c22a854b294ce58a3c9207e223f0840700c91a403b259f727d533b378,
            beaconStateRoot: 0xf9124d8486400eed8d01cc4117b1e19a8a1b3f6caeb2150d5a2260cc5be89d93,
            proofOfInclusionInValidator: proofOfInclusionInValidator,
            proofOfInclusionInValidatorList: proofOfInclusionInValidatorList,
            proofOfInclusionInBeaconState: proofOfInclusionInBeaconState
        });
    }

    function _getBeaconStateProof() internal pure returns (LibEIP4788.BeaconStateProof memory) {
        bytes32[] memory proofOfInclusionInBeaconBlock = new bytes32[](3);
        proofOfInclusionInBeaconBlock[0] =
            0x21ae7285694f3b33cfbdb264203bdbbfc9b18cf1414bcd250b9d2e74a33258be;
        proofOfInclusionInBeaconBlock[1] =
            0x4dcc085a4f2d91447d2f01fd6780073b864a54d250a9144601ee39edfe433d3a;
        proofOfInclusionInBeaconBlock[2] =
            0xe8cc0b7e40eaad3dd2a795ac0e7c68a1d7662e9530ee42a5e0aa919ef8490c7f;

        return LibEIP4788.BeaconStateProof({
            beaconStateRoot: 0xf9124d8486400eed8d01cc4117b1e19a8a1b3f6caeb2150d5a2260cc5be89d93,
            beaconBlockHeaderRoot: 0xf76125a711f3c8145bb562e19797a7b82f5d967ed269abb2cdb54d193ffb76fd,
            proofOfInclusionInBeaconBlock: proofOfInclusionInBeaconBlock
        });
    }

    function _getBeaconProofs() public pure returns (LibEIP4788.BeaconProofs memory) {
        return LibEIP4788.BeaconProofs({
            validatorChunkProof: _getValidatorChunkProof(),
            proposerLookaheadProof: _getProposerLookaheadProof(),
            beaconStateProof: _getBeaconStateProof()
        });
    }

    function _getValidatorPubKey() internal pure returns (BLS.G1Point memory) {
        return BLS.G1Point({
            x_a: 0x0000000000000000000000000000000001fe2d419e4f8075d57064c929a37523,
            x_b: 0xca030f2d24c774dfc2283e28b9a87f91e46c52aca9c3c480bdd42f689fd8c48c,
            y_a: 0x0000000000000000000000000000000016c82a015627a69fedad8aa6a55d16cf,
            y_b: 0x658669e8994ca5c65fb5a39d772a500c7558d8aaf844a43865efbd795ef69e76
        });
    }
}

contract Wrapper {
    function verifyBeaconProofs(
        BLS.G1Point calldata _validatorPubKey,
        LibEIP4788.BeaconProofs calldata _beaconProofs
    )
        external
        view
    {
        LibEIP4788.verifyBeaconProofs(_validatorPubKey, _beaconProofs);
    }
}
