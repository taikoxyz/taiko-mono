// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { ECDSAUpgradeable } from "@ozu/utils/cryptography/ECDSAUpgradeable.sol";
import { Proxied } from "../../common/Proxied.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title GuardianVerifier
contract SGXVerifier is EssentialContract, IVerifier {
    event InstanceAdded(
        uint256 indexed instanceId, address indexed instanceInitPubKey
    );

    struct ProofData {
        uint256 id;
        address newPubKey;
        bytes signature;
    }

    /// @dev For gas savings, we shall assign each SGX instance with an id
    /// so that when we need to set a new pub key, just write storage once.
    uint256 public uniqueVerifiers;

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA
    /// public key. Once that public key is used (by proof verification) it has
    /// to be overwritten by a new one (representing the same instance). This is
    /// due to side-channel protection.
    mapping(uint256 instanceId => address sgxInstance) public sgxRegistry;

    uint256[48] private __gap;

    error SGX_NOT_VALID_SIGNER_OR_ID_MISMATCH();
    error SGX_INVALID_PROOF_SIZE();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param trustedInstances The address array of trusted SGX instances.
    function addToRegistryByOwner(address[] memory trustedInstances)
        external
        onlyOwner
    {
        addTrustedInstances(trustedInstances);
    }

    /// @notice Adds trusted SGX instances to the registry by another SGX
    /// instance.
    /// @param instanceId The id of the SGX instance who is adding new members.
    /// @param newPubKey The new address of the instance.
    /// @param trustedInstances The address array of trusted SGX instances.
    /// @param signature The signature proving authenticity.
    function addToRegistryBySgxInstance(
        uint256 instanceId,
        address newPubKey,
        address[] memory trustedInstances,
        bytes memory signature
    )
        external
    {
        bytes32 signedHash = keccak256(abi.encode(newPubKey, trustedInstances));
        // Would throw in case invalid
        address signer = ECDSAUpgradeable.recover(signedHash, signature);

        if (!isValidInstance(instanceId, signer)) {
            revert SGX_NOT_VALID_SIGNER_OR_ID_MISMATCH();
        }

        // Allow user to add
        addTrustedInstances(trustedInstances);

        // Invalidate current key, because it cannot be used again (side-channel
        // attacks).
        sgxRegistry[instanceId] = newPubKey;
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        // blockId is unused now, but can be used later when supporting
        // different types of proofs.
        uint64,
        address prover,
        bool isContesting,
        TaikoData.BlockEvidence calldata evidence
    )
        external
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        // Size is: 224 bytes
        // Struct encoding data+
        // 2x32 bytes (id + address on a word) + 65 bytes (r,s,v)
        if (evidence.proof.length != 224) {
            revert SGX_INVALID_PROOF_SIZE();
        }

        ProofData memory proofData = abi.decode(evidence.proof, (ProofData));

        bytes32 signedInstance =
            getSignedHash(evidence, prover, proofData.newPubKey);

        // Would throw in case invalid
        address signer =
            ECDSAUpgradeable.recover(signedInstance, proofData.signature);

        if (!isValidInstance(proofData.id, signer)) {
            revert SGX_NOT_VALID_SIGNER_OR_ID_MISMATCH();
        }

        // Invalidate current key, because it cannot be used again (side-channel
        // attacks).
        sgxRegistry[proofData.id] = proofData.newPubKey;
    }

    function getSignedHash(
        TaikoData.BlockEvidence memory evidence,
        address assignedProver,
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
                assignedProver,
                newPubKey
            )
        );
    }

    function isValidInstance(
        uint256 instanceId,
        address instance
    )
        internal
        view
        returns (bool)
    {
        return sgxRegistry[instanceId] == instance;
    }

    function addTrustedInstances(address[] memory trustedInstances) internal {
        for (uint256 i; i < trustedInstances.length; i++) {
            sgxRegistry[uniqueVerifiers] = trustedInstances[i];

            emit InstanceAdded(uniqueVerifiers, trustedInstances[i]);

            uniqueVerifiers++;
        }
    }
}

/// @title ProxiedSGXVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSGXVerifier is Proxied, SGXVerifier { }
