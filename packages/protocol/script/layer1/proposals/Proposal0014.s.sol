// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0014 pnpm proposal`
// To dryrun the proposal actions on L1: `P=0014 pnpm proposal:dryrun:l1`
//
// Registers ZK guest digests from raiko2 v0.2.0 on Shasta verifiers only (additive).
// Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0
contract Proposal0014 is BuildProposal {
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;

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

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](6);

        actions[0] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_PROPOSAL_IMAGE_ID, true))
        });
        actions[1] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_AGGREGATION_IMAGE_ID, true))
        });

        actions[2] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_BN256, true))
        });
        actions[3] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_VKEY_HASH_BYTES, true))
        });
        actions[4] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_BN256, true))
        });
        actions[5] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_VKEY_HASH_BYTES, true))
        });
    }
}
