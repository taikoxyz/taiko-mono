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
    bytes32 public constant RISC0_BATCH_IMAGE_ID = bytes32(uint256(0x1001));
    bytes32 public constant RISC0_SHASTA_AGGREGATION_IMAGE_ID = bytes32(uint256(0x1002));
    bytes32 public constant SP1_BATCH_PROGRAM_VKEY_BN256 = bytes32(uint256(0x2001));
    bytes32 public constant SP1_BATCH_PROGRAM_VKEY_HASH_BYTES = bytes32(uint256(0x2002));
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256 =
        bytes32(uint256(0x2003));
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        bytes32(uint256(0x2004));
    bytes32 public constant SGXRETH_MR_ENCLAVE_NON_EDMM = bytes32(uint256(0x3001));
    bytes32 public constant SGXRETH_MR_ENCLAVE_EDMM = bytes32(uint256(0x3002));
    bytes32 public constant SGXGETH_MR_ENCLAVE_NON_EDMM = bytes32(uint256(0x3003));

    error PlaceholderVerifierIdsNotSet();

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
                Risc0Verifier.setImageIdTrusted,
                (RISC0_SHASTA_AGGREGATION_IMAGE_ID, true)
            )
        });

        // SP1 Shasta: batch program (bn254 + hash_bytes) + shasta aggregation (bn254 + hash_bytes).
        actions[2] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_BATCH_PROGRAM_VKEY_BN256, true)
            )
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
                SP1Verifier.setProgramTrusted,
                (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256, true)
            )
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
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
