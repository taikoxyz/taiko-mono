// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0009 pnpm proposal`
// To dryrun the proposal on L1: `P=0009 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0009 pnpm proposal:dryrun:l2`
contract Proposal0009 is BuildProposal {
    // Shasta / protocol upgrades
    // https://codediff.taiko.xyz/?addr=0xfd019460881e6eec632258222393d5821029b2ac&newimpl=0xdbae46e35c18719e6c78aabf9c8869c4ec84c149&chainid=1
    address public constant PRECONF_WHITELIST_NEW_IMPL = 0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149;
    address public constant PROVER_WHITELIST_PROXY = 0xEa798547d97e345395dA071a0D7ED8144CD612Ae;
    address public constant PACAYA_MAINNET_INBOX_NEW_IMPL =
        0x38Dd73fed93F8051E7A0dDd6FB3b9E7C25668187;
    // https://codediff.taiko.xyz/?addr=0x9e0a24964e5397B566c1ed39258e21aB5E35C77C&newimpl=0x6a4b15e4b0296b2ece03ee9ed74e4a3e3eca68d6&chainid=1
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L1 =
        0x6a4B15E4b0296B2ECE03Ee9Ed74E4A3E3ECA68D6;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0x38e4a497ad70aa0581bac29747b0ea7a53258585&chainid=167000
    address public constant ANCHOR_FORK_ROUTER_L2 = 0x38e4A497aD70aa0581BAc29747b0Ea7a53258585;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000005&newimpl=0x2987f6bef39b03f8522ec38b36af0f7422938eab&chainid=167000
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L2 =
        0x2987F6Bef39b03F8522EC38B36aF0f7422938EAb;

    // ZK verifiers (mainnet, Shasta only; Based on https://github.com/taikoxyz/taiko-mono/pull/21430)
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;

    // SGX attesters (mainnet, reuse existing automata attesters)
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        // L1: 4 protocol upgrades + 6 ZK verifier registrations + 3 SGX mrenclave updates = 13
        actions = new Controller.Action[](13);

        // --- Protocol upgrades (4) ---
        // Upgrade L1 PreconfWhitelist proxy to the Shasta implementation.
        actions[0] = buildUpgradeAction(L1.PRECONF_WHITELIST, PRECONF_WHITELIST_NEW_IMPL);

        // Accept ownership for Shasta ProverWhitelist to finalize DAO ownership transfer.
        actions[1] = Controller.Action({
            target: PROVER_WHITELIST_PROXY,
            value: 0,
            data: abi.encodeWithSignature("acceptOwnership()")
        });

        // Upgrade L1 SignalService proxy to the Shasta fork router.
        actions[2] = buildUpgradeAction(L1.SIGNAL_SERVICE, SIGNAL_SERVICE_FORK_ROUTER_L1);

        // Upgrade L1 Inbox proxy to the Pacaya mainnet implementation.
        actions[3] = buildUpgradeAction(L1.INBOX, PACAYA_MAINNET_INBOX_NEW_IMPL);

        // --- ZK verifiers: Shasta only (raiko zk:v1.16.0) ---
        // We register which proof image/program IDs the Shasta verifiers accept:
        // - "batch" = per-block proof; "shasta-aggregation" = aggregated proof for the Shasta chain.
        // RISC0: 2 image IDs (batch, shasta-aggregation). SP1: 4 program IDs (2 for proposal(batch blocks), 2 for shasta-aggregation).
        actions[4] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x779c032b91d0730ef13b26eafa47b32df7ebdaa4ed766d587fe905530afa2544, true) // boundless-batch
            )
        });
        actions[5] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7, true) // boundless-shasta-aggregation
            )
        });
        // SP1 Shasta: sp1-batch (2 program IDs), sp1-shasta-aggregation (2 program IDs)
        actions[6] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7, true)
            )
        });
        actions[7] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7, true)
            )
        });
        actions[8] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7, true)
            )
        });
        actions[9] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7, true)
            )
        });

        // --- SGX attesters: set trusted MR_ENCLAVE (raiko v1.16.0) ---
        // raiko non-edmm / edmm -> SGXRETH_ATTESTER; gaiko non-edmm -> SGXGETH_ATTESTER
        actions[10] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x59bf7d48610cc8a56ba8a390b68c31a1443297869b174aeacac67dc152820f0e,
                true
            )
        });
        actions[11] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xf285b7cbd78d2b96cdc54cfea3e47d8f510a4b4f91b719c97f8bbb90974f805b,
                true
            )
        });
        actions[12] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xd1f43acede51c4eb2f66b86cce52682edad80b810b9d87fba3a9b67254c91b77,
                true
            )
        });
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](2);

        // Upgrade L2 Anchor proxy to the Shasta fork router.
        actions[0] = buildUpgradeAction(L2.ANCHOR, ANCHOR_FORK_ROUTER_L2);

        // Upgrade L2 SignalService proxy to the Shasta fork router.
        actions[1] = buildUpgradeAction(L2.SIGNAL_SERVICE, SIGNAL_SERVICE_FORK_ROUTER_L2);
    }
}
