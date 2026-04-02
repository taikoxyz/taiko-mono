// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0010 pnpm proposal`
// To dryrun the proposal actions on L1: `P=0010 pnpm proposal:dryrun:l1`
contract Proposal0010 is BuildProposal {
    // Shasta verifiers on taiko_mainnet.
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    // Placeholder IDs to replace before generating calldata or running a dryrun.
    bytes32 public constant RISC0_BATCH_IMAGE_ID =
        bytes32(0x46efe5e0c74976548ee6856789fbfb4929b8f2f9118a119c57ced6e1062e727b);
    bytes32 public constant RISC0_SHASTA_AGGREGATION_IMAGE_ID =
        bytes32(0xdfbce2039ad8b78b236b5a9dceba5d8cee0d9e4638fc8f1fe11a0b2d8bfa039e);
    bytes32 public constant SP1_BATCH_PROGRAM_VKEY_BN256 =
        bytes32(0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8);
    bytes32 public constant SP1_BATCH_PROGRAM_VKEY_HASH_BYTES =
        bytes32(0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8);
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256 =
        bytes32(0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c);
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        bytes32(0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c);
    bytes32 public constant SGXRETH_MR_ENCLAVE_NON_EDMM =
        bytes32(0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099);
    bytes32 public constant SGXRETH_MR_ENCLAVE_EDMM =
        bytes32(0x72258d3cae0e9901d0efc1f630064f1c44f11950bd25fee0b62ec8df84532da2);
    bytes32 public constant SGXGETH_MR_ENCLAVE_NON_EDMM =
        bytes32(0x398be8424f27802b38e6e8d3413bf6a0b187349e68522a218f5bfc00279006ac);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](9);

        // RISC0 Shasta: batch image + shasta-aggregation image.
        actions[0] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_BATCH_IMAGE_ID, true))
        });
        actions[1] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_SHASTA_AGGREGATION_IMAGE_ID, true)
            )
        });

        // SP1 Shasta: batch program (bn254 + hash_bytes) + shasta aggregation (bn254 + hash_bytes).
        actions[2] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_BATCH_PROGRAM_VKEY_BN256, true))
        });
        actions[3] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_BATCH_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
        actions[4] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256, true)
            )
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });

        // SGX attesters: raiko non-edmm / edmm -> SGXRETH_ATTESTER; gaiko non-edmm -> SGXGETH_ATTESTER
        actions[6] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)", SGXRETH_MR_ENCLAVE_NON_EDMM, true
            )
        });
        actions[7] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature("setMrEnclave(bytes32,bool)", SGXRETH_MR_ENCLAVE_EDMM, true)
        });
        actions[8] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)", SGXGETH_MR_ENCLAVE_NON_EDMM, true
            )
        });
    }
}
