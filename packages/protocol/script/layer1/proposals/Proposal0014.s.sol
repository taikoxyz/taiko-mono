// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0014 pnpm proposal`
// To dryrun the proposal actions on L1: `P=0014 pnpm proposal:dryrun:l1`
//
// ENABLE: Registers ZK guest digests from raiko2 v0.2.0 on Shasta verifiers only (`true`).
// Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0
//
// DISABLE: Revokes legacy Shasta ZK digests from Proposal0009 (zk:v1.16.0) and Proposal0010
// (emergency hotfix). Targets ONLY `RISC0_SHASTA_VERIFIER` and `SP1_SHASTA_VERIFIER`
// (`setImageIdTrusted` / `setProgramTrusted` with false). Proposal0009/0010 `setMrEnclave`
// entries on attesters are NOT included.
contract Proposal0014 is BuildProposal {
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;

    // --- ENABLE: raiko2 v0.2.0 (release ZK Guest Digests) ---

    bytes32 public constant RISC0_PROPOSAL_IMAGE_ID =
        bytes32(0x588c81521db5bef5e07f5beab37f1f0b2bba925ac82e733db7cc72e046362754);
    bytes32 public constant RISC0_AGGREGATION_IMAGE_ID =
        bytes32(0x91ddc48054ff4ec62a93bfa0583582d0e04de6ab3928e51e0ea3ee523fee129f);

    bytes32 public constant SP1_PROPOSAL_VKEY_BN256 =
        bytes32(0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580);
    bytes32 public constant SP1_PROPOSAL_VKEY_HASH_BYTES =
        bytes32(0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580);

    bytes32 public constant SP1_AGGREGATION_VKEY_BN256 =
        bytes32(0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5);
    bytes32 public constant SP1_AGGREGATION_VKEY_HASH_BYTES =
        bytes32(0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5);

    // --- DISABLE: Proposal0009 (Proposal0009.s.sol L1 ZK actions 4–9) ---

    bytes32 public constant RISC0_P9_BOUNDLESS_BATCH_IMAGE_ID =
        bytes32(0x779c032b91d0730ef13b26eafa47b32df7ebdaa4ed766d587fe905530afa2544);
    bytes32 public constant RISC0_P9_BOUNDLESS_SHASTA_AGG_IMAGE_ID =
        bytes32(0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7);
    bytes32 public constant SP1_P9_PROG_A =
        bytes32(0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7);
    bytes32 public constant SP1_P9_PROG_B =
        bytes32(0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7);
    bytes32 public constant SP1_P9_PROG_C =
        bytes32(0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7);
    bytes32 public constant SP1_P9_PROG_D =
        bytes32(0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7);

    // --- DISABLE: Proposal0010 (`Proposal0010.s.sol`) ---

    bytes32 public constant RISC0_P10_BATCH_IMAGE_ID =
        bytes32(0x46efe5e0c74976548ee6856789fbfb4929b8f2f9118a119c57ced6e1062e727b);
    bytes32 public constant RISC0_P10_SHASTA_AGG_IMAGE_ID =
        bytes32(0xdfbce2039ad8b78b236b5a9dceba5d8cee0d9e4638fc8f1fe11a0b2d8bfa039e);
    bytes32 public constant SP1_P10_BATCH_VKEY_BN256 =
        bytes32(0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8);
    bytes32 public constant SP1_P10_BATCH_VKEY_HASH_BYTES =
        bytes32(0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8);
    bytes32 public constant SP1_P10_AGG_VKEY_BN256 =
        bytes32(0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c);
    bytes32 public constant SP1_P10_AGG_VKEY_HASH_BYTES =
        bytes32(0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](18);

        // --- ENABLE: raiko2 v0.2.0 ---
        actions[0] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_PROPOSAL_IMAGE_ID, true))
        });
        actions[1] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_AGGREGATION_IMAGE_ID, true)
            )
        });
        actions[2] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_BN256, true))
        });
        actions[3] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_HASH_BYTES, true)
            )
        });
        actions[4] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_BN256, true))
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_HASH_BYTES, true)
            )
        });

        // --- DISABLE: Proposal0009 Shasta ZK digests ---
        actions[6] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_P9_BOUNDLESS_BATCH_IMAGE_ID, false)
            )
        });
        actions[7] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_P9_BOUNDLESS_SHASTA_AGG_IMAGE_ID, false)
            )
        });
        actions[8] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_PROG_A, false))
        });
        actions[9] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_PROG_B, false))
        });
        actions[10] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_PROG_C, false))
        });
        actions[11] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_PROG_D, false))
        });

        // --- DISABLE: Proposal0010 Shasta ZK digests ---
        actions[12] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_P10_BATCH_IMAGE_ID, false)
            )
        });
        actions[13] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (RISC0_P10_SHASTA_AGG_IMAGE_ID, false)
            )
        });
        actions[14] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P10_BATCH_VKEY_BN256, false)
            )
        });
        actions[15] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P10_BATCH_VKEY_HASH_BYTES, false)
            )
        });
        actions[16] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P10_AGG_VKEY_BN256, false))
        });
        actions[17] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P10_AGG_VKEY_HASH_BYTES, false)
            )
        });
    }
}
