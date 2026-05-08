// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0013 pnpm proposal`
// To dryrun the proposal on L1: `P=0013 pnpm proposal:dryrun:l1`
contract Proposal0013 is BuildProposal {
    // Shasta verifiers on taiko_mainnet.
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;

    // raiko2 v0.1.0 guest digests exported from the checked-in Shasta guest ELFs.
    bytes32 public constant RISC0_SHASTA_PROPOSAL_IMAGE_ID =
        0xbee1be4cbe2bdf9b0034a1ab6572061a76019e73189ff96322e58ab229b75f92;
    bytes32 public constant RISC0_SHASTA_AGGREGATION_IMAGE_ID =
        0xa9cc799b246826a3a1b9545e82a290227a65044612a6273b0aaf90dd51169831;
    bytes32 public constant RISC0_SHASTA_BOUNDLESS_AGGREGATION_IMAGE_ID =
        0xcecc85819e15d173c2991577727525b136e820728f7aaaede612f1281cac2249;

    bytes32 public constant SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_BN254 =
        0x0033e2cccc3296e7def7b381a4fb96fafec64f45420b6d24686779ef6236dff1;
    bytes32 public constant SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x19f166660ca5b9f75ef670344fb96faf76327a2a082db49150cef3de6236dff1;
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN254 =
        0x009d26a03d10b4e70eef6a339187c258a7701d6a0150524684cb46b56cf9e540;
    bytes32 public constant SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x4e93501e442d39c35ded4672187c258a3b80eb500541491a09968d6a6cf9e540;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](7);

        // RISC0 Shasta: proposal, aggregation, and boundless aggregation image IDs.
        actions[0] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_SHASTA_PROPOSAL_IMAGE_ID, true)
            )
        });
        actions[1] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_SHASTA_AGGREGATION_IMAGE_ID, true)
            )
        });
        actions[2] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_SHASTA_BOUNDLESS_AGGREGATION_IMAGE_ID, true)
            )
        });

        // SP1 Shasta: proposal and aggregation program digests (vk_bn254 + vk_hash_bytes).
        actions[3] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[4] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[6] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
    }
}
