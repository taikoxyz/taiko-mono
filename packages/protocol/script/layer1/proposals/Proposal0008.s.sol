// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0008 pnpm proposal`
// To dryrun the proposal on L1: `P=0008 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0008 pnpm proposal:dryrun:l2`
contract Proposal0008 is BuildProposal {
    // L1 contracts
    address public constant SP1_VERIFIER = 0xbee1040D0Aab17AE19454384904525aE4A3602B9;
    address public constant RISC0_VERIFIER = 0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](12);

        // SP1 Verifier Actions (6 calls)
        actions[0] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x005208749e76b13f5d72368ee12957ae9de239110b51e00a77b16cbb1c2a9381, true)
            )
        });

        actions[1] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x29043a4f1dac4fd72e46d1dc12957ae96f11c8882d4780296f62d9761c2a9381, true)
            )
        });

        actions[2] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x009d1daf24137c3fb08e1dd65bc517e0f66f07f2c9b2cadb870f235a99ae0905, true)
            )
        });

        actions[3] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x4e8ed79204df0fec11c3bacb3c517e0f33783f9626cb2b6e0e1e46b519ae0905, true)
            )
        });

        actions[4] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00d2c81ddd6751beb8c7656fca189b4b216c7d641afd00d36d5795e7e8a8b53b, true)
            )
        });

        actions[5] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x69640eee59d46fae18ecadf92189b4b20b63eb206bf4034d5aaf2bcf68a8b53b, true)
            )
        });

        // Risc0 Verifier Actions (3 calls)
        actions[6] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x718c5f47ae60739a571681c9f02c1895c791346eece96f58b345159cc6f97c9f, true)
            )
        });

        actions[7] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x3c98171d6744a78a55289aed44281780bca067906e3618aca5ba657595572c25, true)
            )
        });

        actions[8] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x22e8f4b2f051e6630a90fabe99d1034b87daaedb47b62f0b41b1b8158c33dc45, true)
            )
        });

        // SGX Attestation Updates (3 calls)
        actions[9] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xb75d06566bf7f92fc758dd69210d785f549c57436e4529845ce785524848cb6f,
                true
            )
        });

        actions[10] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x1b1d7595fef567e1a97e4b4773e95f9fd136d602f4a40965697609d4191da030,
                true
            )
        });

        actions[11] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x446863e6b9cf3c658d864de1137df2c354781ddea167a9efdc7de8aab74c01ab,
                true
            )
        });
    }
}
