// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibRisc0Constants } from "src/layer1/verifiers/LibRisc0Constants.sol";
import { LibSP1Constants } from "src/layer1/verifiers/LibSP1Constants.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";

// To print the proposal action data: `P=0021 pnpm proposal`
// To dryrun the proposal on L1: `P=0021 pnpm proposal:dryrun:l1`
/// @custom:security-contact security@taiko.xyz
contract Proposal0021 is BuildProposal {
    // Current raiko2 v0.6.0 TEE MRENCLAVE values trusted on the attester proxies.
    bytes32 public constant OLD_SGXGETH_MR_ENCLAVE =
        0x2d2216efbe9d8e80ba24b86606ccd5ce9faf11033d31ad9e5d3c5c89965c8a57;
    bytes32 public constant OLD_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x90c79e65d6d0f83d658ff96cd0ef1204438f20b406c93cf1d4fafa0cff29842e;
    bytes32 public constant OLD_SGXRETH_EDMM_MR_ENCLAVE =
        0x041cadb0541bf8249c368482172d218608f3693975b65f74beb2ed6f0044f951;

    // New raiko2 v0.8.0-rc1 TEE MRENCLAVE values.
    // Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1
    bytes32 public constant NEW_SGXGETH_MR_ENCLAVE =
        0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005;
    bytes32 public constant NEW_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847;
    bytes32 public constant NEW_SGXRETH_EDMM_MR_ENCLAVE =
        0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf;

    error Risc0ImageIdNotSet();
    error Risc0ImageIdNotRotated();
    error SP1ProgramVKeyNotSet();
    error SP1ProgramVKeyNotRotated();
    error SgxMrEnclaveNotSet();
    error SgxMrEnclaveNotRotated();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        _checkRisc0Constants();
        _checkSP1Constants();
        _checkSgxConstants();

        actions = new Controller.Action[](20);

        // 0-3: Rotate the trusted RISC0 image IDs to raiko2 v0.8.0-rc1.
        actions[0] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (LibRisc0Constants.V0_6_0_PROPOSAL_IMAGE_ID, false)
            )
        });
        actions[1] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_6_0_AGGREGATION_IMAGE_ID, false)
            )
        });
        actions[2] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID, true)
            )
        });
        actions[3] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID, true)
            )
        });

        // 4-11: Rotate the trusted SP1 program verification keys the same way.
        actions[4] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_6_0_PROPOSAL_PROGRAM_VKEY_BN254, false)
            )
        });
        actions[5] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_6_0_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[6] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_6_0_AGGREGATION_PROGRAM_VKEY_BN254, false)
            )
        });
        actions[7] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_6_0_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[8] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[9] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
        actions[10] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[11] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });

        // 12-17: Rotate the trusted SGX MRENCLAVE values on the reused attester proxies. MRSIGNER
        // remains unchanged.
        actions[12] = Controller.Action({
            target: L1.SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (OLD_SGXGETH_MR_ENCLAVE, false)
            )
        });
        actions[13] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (OLD_SGXRETH_NON_EDMM_MR_ENCLAVE, false)
            )
        });
        actions[14] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (OLD_SGXRETH_EDMM_MR_ENCLAVE, false)
            )
        });
        actions[15] = Controller.Action({
            target: L1.SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (NEW_SGXGETH_MR_ENCLAVE, true)
            )
        });
        actions[16] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true)
            )
        });
        actions[17] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0021Attestation.setMrEnclave, (NEW_SGXRETH_EDMM_MR_ENCLAVE, true)
            )
        });

        // 18-19: Delete the currently registered raiko2 v0.6.0 SGX instances.
        uint256[] memory instanceIds = new uint256[](1);
        instanceIds[0] = 1;
        actions[18] = Controller.Action({
            target: L1.SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0021SgxVerifier.deleteInstances, (instanceIds))
        });
        actions[19] = Controller.Action({
            target: L1.SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0021SgxVerifier.deleteInstances, (instanceIds))
        });
    }

    function _checkRisc0Constants() private pure {
        require(
            LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID != bytes32(0)
                && LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID != bytes32(0),
            Risc0ImageIdNotSet()
        );
        require(
            LibRisc0Constants.V0_6_0_PROPOSAL_IMAGE_ID
                    != LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID
                && LibRisc0Constants.V0_6_0_AGGREGATION_IMAGE_ID
                    != LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID,
            Risc0ImageIdNotRotated()
        );
    }

    function _checkSP1Constants() private pure {
        require(
            LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES != bytes32(0),
            SP1ProgramVKeyNotSet()
        );
        require(
            LibSP1Constants.V0_6_0_PROPOSAL_PROGRAM_VKEY_BN254
                    != LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254
                && LibSP1Constants.V0_6_0_PROPOSAL_PROGRAM_VKEY_HASH_BYTES
                    != LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES
                && LibSP1Constants.V0_6_0_AGGREGATION_PROGRAM_VKEY_BN254
                    != LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254
                && LibSP1Constants.V0_6_0_AGGREGATION_PROGRAM_VKEY_HASH_BYTES
                    != LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES,
            SP1ProgramVKeyNotRotated()
        );
    }

    function _checkSgxConstants() private pure {
        require(
            NEW_SGXGETH_MR_ENCLAVE != bytes32(0) && NEW_SGXRETH_NON_EDMM_MR_ENCLAVE != bytes32(0)
                && NEW_SGXRETH_EDMM_MR_ENCLAVE != bytes32(0),
            SgxMrEnclaveNotSet()
        );
        require(
            OLD_SGXGETH_MR_ENCLAVE != NEW_SGXGETH_MR_ENCLAVE
                && OLD_SGXRETH_NON_EDMM_MR_ENCLAVE != NEW_SGXRETH_NON_EDMM_MR_ENCLAVE
                && OLD_SGXRETH_EDMM_MR_ENCLAVE != NEW_SGXRETH_EDMM_MR_ENCLAVE,
            SgxMrEnclaveNotRotated()
        );
    }
}

interface IProposal0021Attestation {
    /// @notice Updates whether an SGX application MRENCLAVE is trusted for attestation.
    /// @dev This proposal uses the existing attester proxy interface from the live SGX verifiers.
    /// @param _mrEnclave The SGX application enclave measurement to update.
    /// @param _trusted True to trust the measurement, false to untrust it.
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
}

interface IProposal0021SgxVerifier {
    /// @notice Deletes SGX verifier instances by instance ID.
    /// @dev Deleting the old release instances is required because the live verifier registry does
    /// not re-check MRENCLAVE trust for already registered instances at proof time.
    /// @param _ids The SGX instance IDs to delete.
    function deleteInstances(uint256[] calldata _ids) external;
}
