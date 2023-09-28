// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { Proxied } from "../../common/Proxied.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title GuardianVerifier
contract SGXVerifier is EssentialContract, IVerifier {
    using LibAddress for address;

    struct ProofData {
        address currentPubKey;
        address newPubKey;
        bytes signature;
    }
    
    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA public key. Once that public key is used (by proof verification) it has to be overwritten by a new one (representing the same instance). This is due to side-channel protection.
    mapping(address sgxInstance => bool truested) sgxRegistry;
    uint256[49] private __gap;

    error SGX_NOT_TRUSTED();
    error SGX_INVALID_PROOF_DATA();
    error SGX_INVALID_PROOF_SIGNATURE();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param trustedInstances The address array of trusted SGX instances.
    function addToRegistry(address[] memory trustedInstances) external onlyOwner {
        for (uint256 i; i < trustedInstances.length; i++) {
            sgxRegistry[trustedInstances[i]] = true;
        }
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        // blockId is unused now, but can be used later when supporting
        // different types of proofs.
        uint64,
        address,
        bool isContesting,
        TaikoData.BlockEvidence calldata evidence
    )
        external
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        // At least (worst case) the 2 x 32 bytes shall be encoded (current and new pubKey)
        if(evidence.proof.length < 64) {
            revert SGX_INVALID_PROOF_DATA();
        }
        ProofData memory proofData =
            abi.decode(evidence.proof, (ProofData));

        if(!sgxRegistry[proofData.currentPubKey]) {
            revert SGX_NOT_TRUSTED();
        }

        bytes32 signedInstance = getSignedHash(evidence,proofData.currentPubKey, proofData.newPubKey);

        if(!proofData.currentPubKey.isValidSignature(signedInstance, proofData.signature)) {
            revert SGX_INVALID_PROOF_SIGNATURE();
        }

        // Invalidate current key, because it cannot be used again (side-channel attacks).
        sgxRegistry[proofData.currentPubKey] = false;
        sgxRegistry[proofData.newPubKey] = true;
    }

    function getSignedHash(
        TaikoData.BlockEvidence memory evidence,
        address currentInstancePubKey,
        address newPubKey
    )
        public
        pure
        returns (bytes32 signedHash)
    {
        return keccak256(
            abi.encode(
                evidence.metaHash,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                evidence.graffiti,
                currentInstancePubKey,
                newPubKey
            )
        );
    }
}

/// @title ProxiedSGXVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSGXVerifier is Proxied, SGXVerifier { }
