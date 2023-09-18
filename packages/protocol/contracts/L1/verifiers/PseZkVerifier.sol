// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { IEvidenceVerifier } from "./IEvidenceVerifier.sol";
import { LibBytesUtils } from "../../thirdparty/LibBytesUtils.sol";
import { Proxied } from "../../common/Proxied.sol";
import { TaikoData } from "../TaikoData.sol";

/// @title PseZkVerifier
/// @notice See the documentation in {IEvidenceVerifier}.
contract PseZkVerifier is EssentialContract, IEvidenceVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc IEvidenceVerifier
    function verifyProof(
        // blockId is unused now, but can be used later when supporting
        // different types of proofs.
        uint64,
        address prover,
        bool isContesting,
        TaikoData.BlockEvidence calldata evidence
    )
        external
        view
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        bytes32 instance = getInstance(prover, evidence);

        // Validate the instance using bytes utilities.
        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(evidence.proof, 2, 32),
                bytes.concat(bytes16(0), bytes16(instance))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(evidence.proof, 34, 32),
                bytes.concat(bytes16(0), bytes16(uint128(uint256(instance))))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        // Extract verifier ID from the proof.
        uint16 verifierId = uint16(bytes2(evidence.proof[0:2]));

        // Delegate to the ZKP verifier library to validate the proof.

        // Resolve the verifier's name and obtain its address.
        address verifierAddress = resolve(getVerifierName(verifierId), false);

        // Call the verifier contract with the provided proof.
        (bool verified, bytes memory ret) =
            verifierAddress.staticcall(bytes.concat(evidence.proof[2:]));

        // Check if the proof is valid.
        if (!verified || ret.length != 32 || bytes32(ret) != keccak256("taiko"))
        {
            revert L1_INVALID_PROOF();
        }
    }

    function getInstance(
        address prover,
        TaikoData.BlockEvidence memory evidence
    )
        internal
        pure
        returns (bytes32 instance)
    {
        return keccak256(
            abi.encode(
                evidence.metaHash,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                evidence.graffiti,
                prover
            )
        );
    }

    function getVerifierName(uint16 id) internal pure returns (bytes32) {
        return bytes32(uint256(0x1000000) + id);
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedPseZkVerifier is Proxied, PseZkVerifier { }
