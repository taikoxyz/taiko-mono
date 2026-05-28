// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0014 pnpm proposal`
// To dryrun the proposal actions on L1: `P=0014 pnpm proposal:dryrun:l1`
//
// ENABLE: Registers SP1 guest digests from raiko2 v0.2.0 on the Shasta SP1 verifier (`true`).
// Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0
//
// DISABLE: Revokes legacy Shasta SP1 digests from Proposal0009 (zk:v1.16.0) and Proposal0010
// (emergency hotfix). Targets ONLY `SP1_SHASTA_VERIFIER` (`setProgramTrusted` with false).
// RISC0 image IDs and Proposal0009/0010 `setMrEnclave` entries on attesters are NOT included.
contract Proposal0014 is BuildProposal {
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;

    // --- ENABLE: raiko2 v0.2.0 (release SP1 guest digests) ---

    bytes32 public constant SP1_PROPOSAL_VKEY_BN256 =
        bytes32(0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580);
    bytes32 public constant SP1_PROPOSAL_VKEY_HASH_BYTES =
        bytes32(0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580);

    bytes32 public constant SP1_AGGREGATION_VKEY_BN256 =
        bytes32(0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5);
    bytes32 public constant SP1_AGGREGATION_VKEY_HASH_BYTES =
        bytes32(0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5);

    // --- DISABLE: Proposal0009 (Proposal0009.s.sol L1 ZK actions 4–9) ---

    bytes32 public constant SP1_P9_BATCH_VKEY_BN256 =
        bytes32(0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7);
    bytes32 public constant SP1_P9_BATCH_VKEY_HASH_BYTES =
        bytes32(0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7);
    bytes32 public constant SP1_P9_AGG_VKEY_BN256 =
        bytes32(0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7);
    bytes32 public constant SP1_P9_AGG_VKEY_HASH_BYTES =
        bytes32(0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7);

    // --- DISABLE: Proposal0010 (`Proposal0010.s.sol`) ---

    bytes32 public constant SP1_P10_BATCH_VKEY_BN256 =
        bytes32(0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8);
    bytes32 public constant SP1_P10_BATCH_VKEY_HASH_BYTES =
        bytes32(0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8);
    bytes32 public constant SP1_P10_AGG_VKEY_BN256 =
        bytes32(0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c);
    bytes32 public constant SP1_P10_AGG_VKEY_HASH_BYTES =
        bytes32(0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](12);

        // --- ENABLE: raiko2 v0.2.0 ---
        actions[0] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_BN256, true))
        });
        actions[1] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_HASH_BYTES, true)
            )
        });
        actions[2] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_BN256, true))
        });
        actions[3] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_HASH_BYTES, true)
            )
        });

        // --- DISABLE: Proposal0009 Shasta ZK digests ---
        actions[4] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_BATCH_VKEY_BN256, false))
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P9_BATCH_VKEY_HASH_BYTES, false)
            )
        });
        actions[6] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_AGG_VKEY_BN256, false))
        });
        actions[7] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P9_AGG_VKEY_HASH_BYTES, false))
        });

        // --- DISABLE: Proposal0010 Shasta ZK digests ---
        actions[8] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P10_BATCH_VKEY_BN256, false))
        });
        actions[9] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P10_BATCH_VKEY_HASH_BYTES, false)
            )
        });
        actions[10] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_P10_AGG_VKEY_BN256, false))
        });
        actions[11] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_P10_AGG_VKEY_HASH_BYTES, false)
            )
        });
    }
}
