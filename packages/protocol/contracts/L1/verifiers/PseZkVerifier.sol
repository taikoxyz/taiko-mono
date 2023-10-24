// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { Lib4844 } from "../../4844/Lib4844.sol";
import { Proxied } from "../../common/Proxied.sol";
import { Proxied } from "../../common/Proxied.sol";
import { LibBytesUtils } from "../../thirdparty/LibBytesUtils.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title PseZkVerifier
/// @notice See the documentation in {IVerifier}.
contract PseZkVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    struct PointProof {
        bytes32 txListHash;
        uint256 pointValue;
        bytes1[48] pointCommitment;
        bytes1[48] pointProof;
    }

    struct PseZkEvmProof {
        uint16 verifierId;
        bytes zkp;
        bytes pointProof;
    }

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        uint64, /*blockId*/
        address prover,
        bool isContesting,
        bool usingBlob,
        bytes32 blobHash,
        TaikoData.BlockEvidence calldata evidence
    )
        external
        view
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        PseZkEvmProof memory proof = abi.decode(evidence.proof, (PseZkEvmProof));

        bytes32 instance;

        if (usingBlob) {
            PointProof memory pf = abi.decode(proof.pointProof, (PointProof));
            bytes32 x = keccak256(abi.encodePacked(blobHash, pf.txListHash));
            Lib4844.evaluatePoint({
                blobHash: blobHash,
                x: uint256(x) % Lib4844.BLS_MODULUS,
                y: pf.pointValue,
                commitment: pf.pointCommitment,
                proof: pf.pointProof
            });

            instance = calcInstance({
                prover: prover,
                blobHash: blobHash,
                txListHash: pf.txListHash,
                pointValue: pf.pointValue,
                evidence: evidence
            });
        } else {
            assert(proof.pointProof.length == 0);
            instance = calcInstance({
                prover: prover,
                blobHash: 0,
                txListHash: blobHash, // blobHash == txListHash
                pointValue: 0,
                evidence: evidence
            });
        }

        // Validate the instance using bytes utilities.
        bool verified = LibBytesUtils.equal(
            LibBytesUtils.slice(proof.zkp, 0, 32),
            bytes.concat(bytes16(0), bytes16(instance))
        );
        if (!verified) revert L1_INVALID_PROOF();

        verified = LibBytesUtils.equal(
            LibBytesUtils.slice(proof.zkp, 32, 32),
            bytes.concat(bytes16(0), bytes16(uint128(uint256(instance))))
        );
        if (!verified) revert L1_INVALID_PROOF();

        // Delegate to the ZKP verifier library to validate the proof.
        // Resolve the verifier's name and obtain its address.
        address verifierAddress =
            resolve(getVerifierName(proof.verifierId), false);

        // Call the verifier contract with the provided proof.
        bytes memory ret;
        (verified, ret) = verifierAddress.staticcall(bytes.concat(proof.zkp));

        // Check if the proof is valid.
        if (!verified) revert L1_INVALID_PROOF();
        if (ret.length != 32) revert L1_INVALID_PROOF();
        if (bytes32(ret) != keccak256("taiko")) revert L1_INVALID_PROOF();
    }

    function calcInstance(
        address prover,
        bytes32 blobHash,
        bytes32 txListHash,
        uint256 pointValue,
        TaikoData.BlockEvidence memory evidence
    )
        public
        pure
        returns (bytes32 instance)
    {
        return keccak256(
            abi.encodePacked(
                evidence.metaHash,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                evidence.graffiti,
                prover,
                blobHash,
                txListHash,
                pointValue
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
