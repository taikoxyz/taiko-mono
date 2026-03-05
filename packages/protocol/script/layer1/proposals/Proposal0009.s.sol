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

    // ZK verifiers (mainnet, from https://github.com/taikoxyz/raiko/blob/main/host/config/chain_spec_list_default.json)
    address public constant SP1_PACAYA_VERIFIER = 0xbee1040D0Aab17AE19454384904525aE4A3602B9;
    address public constant RISC0_PACAYA_VERIFIER = 0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE;
    address public constant SP1_SHASTA_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant RISC0_SHASTA_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;

    // SGX attesters (mainnet, same chainspec as ZK verifiers)
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        // 4 Shasta/protocol + 18 ZK (RISC0/SP1 PACAYA+SHASTA) + 3 SGX = 25
        actions = new Controller.Action[](25);

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

        // --- ZK: RISC0 image IDs for PACAYA (3) ---
        actions[4] = Controller.Action({
            target: RISC0_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x33ac277d74776b9199ffe913addadb6a49fafb07153a7faa874593629377d513, true)
            )
        });
        actions[5] = Controller.Action({
            target: RISC0_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x7280f15f5c0a9b1354907d862c0b03caf3f33d65bb83e6db56bbd3cf0dd79fd2, true)
            )
        });
        actions[6] = Controller.Action({
            target: RISC0_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7, true)
            )
        });

        // --- ZK: SP1 programs for PACAYA (6) ---
        actions[7] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00711b07e4437d1fba25154fc88c2766496448350d0e0a40883163651c6222c1, true)
            )
        });
        actions[8] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x388d83f210df47ee44a2a9f908c276644b2241a8343829021062c6ca1c6222c1, true)
            )
        });
        actions[9] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00d9389b2b0ce723bb0261ba1e77fed3fc97c3a217b09b6689bcd0ffd801657b, true)
            )
        });
        actions[10] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x6c9c4d954339c8ee604c3743677fed3f64be1d105ec26d9a1379a1ff5801657b, true)
            )
        });
        actions[11] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7, true)
            )
        });
        actions[12] = Controller.Action({
            target: SP1_PACAYA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7, true)
            )
        });

        // --- ZK: RISC0 image IDs for SHASTA (3) ---
        actions[13] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x33ac277d74776b9199ffe913addadb6a49fafb07153a7faa874593629377d513, true)
            )
        });
        actions[14] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x7280f15f5c0a9b1354907d862c0b03caf3f33d65bb83e6db56bbd3cf0dd79fd2, true)
            )
        });
        actions[15] = Controller.Action({
            target: RISC0_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7, true)
            )
        });

        // --- ZK: SP1 programs for SHASTA (6) ---
        actions[16] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00711b07e4437d1fba25154fc88c2766496448350d0e0a40883163651c6222c1, true)
            )
        });
        actions[17] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x388d83f210df47ee44a2a9f908c276644b2241a8343829021062c6ca1c6222c1, true)
            )
        });
        actions[18] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00d9389b2b0ce723bb0261ba1e77fed3fc97c3a217b09b6689bcd0ffd801657b, true)
            )
        });
        actions[19] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x6c9c4d954339c8ee604c3743677fed3f64be1d105ec26d9a1379a1ff5801657b, true)
            )
        });
        actions[20] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7, true)
            )
        });
        actions[21] = Controller.Action({
            target: SP1_SHASTA_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7, true)
            )
        });

        // --- SGX: raiko + gaiko mrenclave (raiko v1.15.0, https://github.com/taikoxyz/raiko/pull/670) ---
        actions[22] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xe4a6a74d2a7b86a14cb8739e33268d5eeef6cd7e6a14cc642d6f8764820169be,
                true
            )
        });
        actions[23] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x775e1a01db59b5e892ef3cd883036d6e9630af71bc3b3550be8999eaefd339c1,
                true
            )
        });
        actions[24] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xb99907155a0078cfe3e4927692f982a052b1b2ca005fccaebf08f3c8dfe21eb4,
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
