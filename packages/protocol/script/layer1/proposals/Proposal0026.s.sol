// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibRisc0Constants } from "src/layer1/verifiers/LibRisc0Constants.sol";
import { LibSGXConstants } from "src/layer1/verifiers/LibSGXConstants.sol";
import { LibSP1Constants } from "src/layer1/verifiers/LibSP1Constants.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";

// To print the proposal action data: `P=0026 pnpm proposal`
// To dryrun the proposal on L1: `P=0026 pnpm proposal:dryrun:l1`
/// @custom:security-contact security@taiko.xyz
contract Proposal0026 is BuildProposal {
    /// @dev The `MainnetInbox` implementation the inbox proxy upgrades to: the live configuration
    /// with `basefeeSharingPctg` raised from 75 to 100. Deployed by `DeployInboxUpgradeL1` on
    /// Ethereum mainnet.
    /// See `Proposal0026.md` for the deployed implementation's codediff.
    address public constant MAINNET_INBOX_NEW_IMPL = 0xA18431d42C8dF9778905fBEa912aCF1881b49D2e;

    error ImplementationNotDeployed();
    error Risc0ImageIdNotSet();
    error Risc0ImageIdNotRotated();
    error SP1ProgramVKeyNotSet();
    error SP1ProgramVKeyNotRotated();
    error SgxMrEnclaveNotSet();
    error SgxMrEnclaveNotRotated();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory) {
        return buildL1Actions(MAINNET_INBOX_NEW_IMPL);
    }

    /// @dev Encodes the L1 leg against an injectable implementation so tests can assert the
    /// complete batch independently of the deployed inbox implementation address.
    /// @param _inboxImpl The implementation the inbox proxy upgrades to.
    /// @return actions The complete 21-action L1 batch.
    function buildL1Actions(address _inboxImpl)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(_inboxImpl != address(0), ImplementationNotDeployed());
        _checkRisc0Constants();
        _checkSP1Constants();
        _checkSgxConstants();

        actions = new Controller.Action[](21);

        // 0: Upgrade the inbox to the implementation that pays the whole basefee to the coinbase.
        // Immutables only: the new implementation carries the live proof verifier, proposer
        // checker, prover whitelist, signal service and bond token, and the same numeric
        // configuration apart from basefeeSharingPctg. No initializer runs, and the proxy's
        // storage (core state, proposal hashes, forced inclusion queue, bonds) is untouched.
        // Proposals already made keep the percentage they were proposed with; the first propose
        // after execution carries 100.
        actions[0] = buildUpgradeAction(L1.INBOX, _inboxImpl);

        // 1-4: Rotate the trusted RISC0 image IDs to raiko2 v0.9.0-rc1.
        actions[1] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID, false)
            )
        });
        actions[2] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID, false)
            )
        });
        actions[3] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_9_0_RC1_PROPOSAL_IMAGE_ID, true)
            )
        });
        actions[4] = Controller.Action({
            target: L1.RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (LibRisc0Constants.V0_9_0_RC1_AGGREGATION_IMAGE_ID, true)
            )
        });

        // 5-12: Rotate the trusted SP1 program verification keys the same way.
        actions[5] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254, false)
            )
        });
        actions[6] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[7] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254, false)
            )
        });
        actions[8] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[9] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[10] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
        actions[11] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254, true)
            )
        });
        actions[12] = Controller.Action({
            target: L1.SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });

        // 13-18: Rotate the trusted SGX MRENCLAVE values on the reused attester proxies. MRSIGNER
        // and the deployed attribute policy remain unchanged.
        actions[13] = Controller.Action({
            target: L1.SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_8_0_RC1_SGXGETH_MR_ENCLAVE, false)
            )
        });
        actions[14] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_8_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE, false)
            )
        });
        actions[15] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_8_0_RC1_SGXRETH_EDMM_MR_ENCLAVE, false)
            )
        });
        actions[16] = Controller.Action({
            target: L1.SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_9_0_RC1_SGXGETH_MR_ENCLAVE, true)
            )
        });
        actions[17] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_9_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE, true)
            )
        });
        actions[18] = Controller.Action({
            target: L1.SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(
                IProposal0026Attestation.setMrEnclave,
                (LibSGXConstants.V0_9_0_RC1_SGXRETH_EDMM_MR_ENCLAVE, true)
            )
        });

        // 19-20: Delete the currently registered raiko2 v0.8.0-rc1 SGX instances. Registering
        // fresh v0.9.0-rc1 instances is a separate post-execution operation.
        uint256[] memory instanceIds = new uint256[](1);
        instanceIds[0] = 2;
        actions[19] = Controller.Action({
            target: L1.SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0026SgxVerifier.deleteInstances, (instanceIds))
        });
        actions[20] = Controller.Action({
            target: L1.SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0026SgxVerifier.deleteInstances, (instanceIds))
        });
    }

    function _checkRisc0Constants() private pure {
        require(
            LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID != bytes32(0)
                && LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID != bytes32(0)
                && LibRisc0Constants.V0_9_0_RC1_PROPOSAL_IMAGE_ID != bytes32(0)
                && LibRisc0Constants.V0_9_0_RC1_AGGREGATION_IMAGE_ID != bytes32(0),
            Risc0ImageIdNotSet()
        );
        require(
            LibRisc0Constants.V0_8_0_RC1_PROPOSAL_IMAGE_ID
                    != LibRisc0Constants.V0_9_0_RC1_PROPOSAL_IMAGE_ID
                && LibRisc0Constants.V0_8_0_RC1_AGGREGATION_IMAGE_ID
                    != LibRisc0Constants.V0_9_0_RC1_AGGREGATION_IMAGE_ID,
            Risc0ImageIdNotRotated()
        );
    }

    function _checkSP1Constants() private pure {
        require(
            LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254 != bytes32(0)
                && LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES != bytes32(0),
            SP1ProgramVKeyNotSet()
        );
        require(
            LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254
                    != LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254
                && LibSP1Constants.V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES
                    != LibSP1Constants.V0_9_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254
                    != LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254
                && LibSP1Constants.V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES
                    != LibSP1Constants.V0_9_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES,
            SP1ProgramVKeyNotRotated()
        );
    }

    function _checkSgxConstants() private pure {
        require(
            LibSGXConstants.V0_8_0_RC1_SGXGETH_MR_ENCLAVE != bytes32(0)
                && LibSGXConstants.V0_8_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE != bytes32(0)
                && LibSGXConstants.V0_8_0_RC1_SGXRETH_EDMM_MR_ENCLAVE != bytes32(0)
                && LibSGXConstants.V0_9_0_RC1_SGXGETH_MR_ENCLAVE != bytes32(0)
                && LibSGXConstants.V0_9_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE != bytes32(0)
                && LibSGXConstants.V0_9_0_RC1_SGXRETH_EDMM_MR_ENCLAVE != bytes32(0),
            SgxMrEnclaveNotSet()
        );
        require(
            LibSGXConstants.V0_8_0_RC1_SGXGETH_MR_ENCLAVE
                    != LibSGXConstants.V0_9_0_RC1_SGXGETH_MR_ENCLAVE
                && LibSGXConstants.V0_8_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE
                    != LibSGXConstants.V0_9_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE
                && LibSGXConstants.V0_8_0_RC1_SGXRETH_EDMM_MR_ENCLAVE
                    != LibSGXConstants.V0_9_0_RC1_SGXRETH_EDMM_MR_ENCLAVE,
            SgxMrEnclaveNotRotated()
        );
    }
}

interface IProposal0026Attestation {
    /// @notice Updates whether an SGX application MRENCLAVE is trusted for attestation.
    /// @param _mrEnclave The SGX application enclave measurement to update.
    /// @param _trusted True to trust the measurement, false to untrust it.
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
}

interface IProposal0026SgxVerifier {
    /// @notice Deletes SGX verifier instances by instance ID.
    /// @param _ids The SGX instance IDs to delete.
    function deleteInstances(uint256[] calldata _ids) external;
}
