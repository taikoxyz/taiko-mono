// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0020 pnpm proposal`
// To dryrun the proposal on L1: `P=0020 pnpm proposal:dryrun:l1`
contract Proposal0020 is BuildProposal {
    // SGX sub-verifiers and attester proxies reused from Proposal0017/Proposal0019.
    address public constant SGXGETH_VERIFIER = 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee;
    address public constant SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    // ZK sub-verifiers wired into the active ZkRequiredVerifier.
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;

    // Currently trusted raiko2 v0.6.0 ZK IDs, set by Proposal0019.
    bytes32 public constant OLD_RISC0_PROPOSAL_IMAGE_ID =
        0x5a818b4c7dc80e9ba85d55492c20c263c67238724e3982f76d15a158e501210b;
    bytes32 public constant OLD_RISC0_AGGREGATION_IMAGE_ID =
        0x9cfcc1b34a98853c3c5873a4d456726e528246f7f03a4ea35f27c2543aa6e7f0;
    bytes32 public constant OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256 =
        0x00ad090221a8fa0f09e1be7a53feb67be010f01310d4b2314a69d10152ee1ce0;
    bytes32 public constant OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x568481106a3e83c23c37cf4a3feb67be008780984352c8c514d3a20252ee1ce0;
    bytes32 public constant OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256 =
        0x000b11691352e55fcf64f62620cefaa700161600093f2751032fe71ea912264d;
    bytes32 public constant OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x0588b48954b957f36c9ec4c40cefaa7000b0b00024fc9d44065fce3d2912264d;

    // New raiko2 v0.8.0-rc1 ZK IDs.
    // Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1
    bytes32 public constant NEW_RISC0_PROPOSAL_IMAGE_ID =
        0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10;
    bytes32 public constant NEW_RISC0_AGGREGATION_IMAGE_ID =
        0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7;
    bytes32 public constant NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256 =
        0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7;
    bytes32 public constant NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7;
    bytes32 public constant NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256 =
        0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6;
    bytes32 public constant NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6;

    // Current raiko2 v0.6.0 TEE MRENCLAVE values trusted on the attester proxies.
    bytes32 public constant OLD_SGXGETH_MR_ENCLAVE = 0x2d2216efbe9d8e80ba24b86606ccd5ce9faf11033d31ad9e5d3c5c89965c8a57;
    bytes32 public constant OLD_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x90c79e65d6d0f83d658ff96cd0ef1204438f20b406c93cf1d4fafa0cff29842e;
    bytes32 public constant OLD_SGXRETH_EDMM_MR_ENCLAVE =
        0x041cadb0541bf8249c368482172d218608f3693975b65f74beb2ed6f0044f951;

    // New raiko2 v0.8.0-rc1 TEE MRENCLAVE values.
    // Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1
    bytes32 public constant NEW_SGXGETH_MR_ENCLAVE = 0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005;
    bytes32 public constant NEW_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847;
    bytes32 public constant NEW_SGXRETH_EDMM_MR_ENCLAVE =
        0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf;

    error ZkImageIdNotSet();
    error SgxMrEnclaveNotSet();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(
            NEW_RISC0_PROPOSAL_IMAGE_ID != bytes32(0) && NEW_RISC0_AGGREGATION_IMAGE_ID != bytes32(0), ZkImageIdNotSet()
        );
        require(
            NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256 != bytes32(0) && NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256 != bytes32(0)
                && NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES != bytes32(0),
            ZkImageIdNotSet()
        );
        require(
            NEW_SGXGETH_MR_ENCLAVE != bytes32(0) && NEW_SGXRETH_NON_EDMM_MR_ENCLAVE != bytes32(0)
                && NEW_SGXRETH_EDMM_MR_ENCLAVE != bytes32(0),
            SgxMrEnclaveNotSet()
        );

        actions = new Controller.Action[](20);

        // 0-3: Rotate the trusted RISC0 image IDs to raiko2 v0.8.0-rc1.
        actions[0] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (OLD_RISC0_PROPOSAL_IMAGE_ID, false))
        });
        actions[1] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (OLD_RISC0_AGGREGATION_IMAGE_ID, false))
        });
        actions[2] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (NEW_RISC0_PROPOSAL_IMAGE_ID, true))
        });
        actions[3] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (NEW_RISC0_AGGREGATION_IMAGE_ID, true))
        });

        // 4-11: Rotate the trusted SP1 program verification keys the same way.
        actions[4] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256, false))
        });
        actions[5] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false))
        });
        actions[6] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256, false))
        });
        actions[7] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false))
        });
        actions[8] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256, true))
        });
        actions[9] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true))
        });
        actions[10] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256, true))
        });
        actions[11] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(SP1Verifier.setProgramTrusted, (NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true))
        });

        // 12-17: Rotate the trusted SGX MRENCLAVE values on the reused attester proxies. MRSIGNER
        // remains unchanged.
        actions[12] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (OLD_SGXGETH_MR_ENCLAVE, false))
        });
        actions[13] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (OLD_SGXRETH_NON_EDMM_MR_ENCLAVE, false))
        });
        actions[14] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (OLD_SGXRETH_EDMM_MR_ENCLAVE, false))
        });
        actions[15] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (NEW_SGXGETH_MR_ENCLAVE, true))
        });
        actions[16] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true))
        });
        actions[17] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0020Attestation.setMrEnclave, (NEW_SGXRETH_EDMM_MR_ENCLAVE, true))
        });

        // 18-19: Delete the currently registered raiko2 v0.6.0 SGX instances.
        uint256[] memory instanceIds = new uint256[](1);
        instanceIds[0] = 1;
        actions[18] = Controller.Action({
            target: SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0020SgxVerifier.deleteInstances, (instanceIds))
        });
        actions[19] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0020SgxVerifier.deleteInstances, (instanceIds))
        });
    }
}

interface IProposal0020Attestation {
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
}

interface IProposal0020SgxVerifier {
    function deleteInstances(uint256[] calldata _ids) external;
}
