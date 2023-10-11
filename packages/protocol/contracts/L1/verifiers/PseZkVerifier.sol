// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibBytesUtils } from "../../thirdparty/LibBytesUtils.sol";
import { Proxied } from "../../common/Proxied.sol";
import { Lib4844 } from "../../L1/libs/Lib4844.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title PseZkVerifier
/// @notice See the documentation in {IVerifier}.
contract PseZkVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    struct ProofData {
        bytes32 txListHash;
        uint256 pointValue;
        bytes1[48] pointCommitment;
        bytes1[48] pointProof;
        uint16 verifierId;
        bytes zkp;
    }

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        // blockId is unused now, but can be used later when supporting
        // different types of proofs.
        uint64,
        address prover,
        bool isContesting,
        bytes32 blobVersionHash,
        TaikoData.BlockEvidence calldata evidence
    )
        external
        view
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        ProofData memory data = abi.decode(evidence.proof, (ProofData));
        // Verify blob
        {
            // Hash and x are both deterministic and can be calculated off-chain
            // by provers
            // We can use `blobVersionHash` to replace `evidence.metaHash`, but
            // `evidence.metaHash` is even better.
            bytes32 hash =
                keccak256(abi.encodePacked(evidence.metaHash, data.txListHash));
            uint256 x = uint256(hash) % Lib4844.FIELD_ELEMENTS_PERBLOB;

            // Question: What if x * 32 is larger than the blob data size

            // Question: how to calculate pointCommitment and pointProof
            // offchain?
            Lib4844.point_evaluation_precompile(
                blobVersionHash,
                x,
                data.pointValue,
                data.pointCommitment,
                data.pointProof
            );
        }

        // Verify ZKP
        bytes32 instance = getInstance(prover, evidence);

        // Validate the instance using bytes utilities.
        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(data.zkp, 0, 32),
                bytes.concat(bytes16(0), bytes16(instance))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(data.zkp, 32, 32),
                bytes.concat(bytes16(0), bytes16(uint128(uint256(instance))))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        // Delegate to the ZKP verifier library to validate the proof.
        // Resolve the verifier's name and obtain its address.
        address verifierAddress =
            resolve(getVerifierName(data.verifierId), false);

        // Call the verifier contract with the provided proof.
        (bool verified, bytes memory ret) =
            verifierAddress.staticcall(bytes.concat(data.zkp));

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
        public
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

    function getVerifierName(uint16 id) public pure returns (bytes32) {
        return bytes32(uint256(0x1000000) + id);
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedPseZkVerifier is Proxied, PseZkVerifier { }
