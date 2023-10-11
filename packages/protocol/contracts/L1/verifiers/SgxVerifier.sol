// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ECDSAUpgradeable } from "@ozu/utils/cryptography/ECDSAUpgradeable.sol";

import { EssentialContract } from "../../common/EssentialContract.sol";
import { Proxied } from "../../common/Proxied.sol";
import { LibBytesUtils } from "../../thirdparty/LibBytesUtils.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title GuardianVerifier
contract SgxVerifier is EssentialContract, IVerifier {
    using ECDSAUpgradeable for bytes32;

    uint256 public constant INSTANCE_EXPIRY = 180 days;

    event InstanceAdded(uint256 indexed instanceId, address instanceInitAddress, uint64 timstamp);
    event InstanceChanged(uint256 indexed instanceId, address oldInstance, address newInstance, uint64 timstamp);

    struct InstanceData {
        address activeAddress;
        uint64 effectiveSince; // We can calculate if expired
    }

    /// @dev For gas savings, we shall assign each SGX instance with an id
    /// so that when we need to set a new pub key, just write storage once.
    uint256 public uniqueVerifiers;

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA
    /// public key (or rather ethereum address). Once that address is used (by
    /// proof verification) it has to be overwritten by a new one (representing
    /// the same instance). This is due to side-channel protection. Also this
    /// public key shall expire after some time. (For now it is a long enough 6
    /// months setting.)
    mapping(uint256 instanceId => InstanceData sgxInstance) public sgxRegistry;

    uint256[48] private __gap;

    error SGX_INVALID_PROOF_SIZE();
    error SGX_INSTANCE_INVALID();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param trustedInstances The address array of trusted SGX instances.
    function registerInstances(address[] memory trustedInstances)
        external
        onlyOwner
    {
        addTrustedInstances(trustedInstances);
    }

    /// @notice Adds trusted SGX instances to the registry by another SGX
    /// instance.
    /// @param instanceId The id of the SGX instance who is adding new members.
    /// @param newAddress The new address of the instance.
    /// @param trustedInstances The address array of trusted SGX instances.
    /// @param signature The signature proving authenticity.
    function registerInstancesBySgx(
        uint256 instanceId,
        address newAddress,
        address[] memory trustedInstances,
        bytes memory signature
    )
        external
    {
        bytes32 signedHash = keccak256(
            abi.encode("REGISTER_SGX_INSTANCE", newAddress, trustedInstances)
        );
        // Would throw in case invalid
        address signer = signedHash.recover(signature);

        if (!isInstanceValid(instanceId, signer)) {
            revert SGX_INSTANCE_INVALID();
        }

        // Allow user to add
        addTrustedInstances(trustedInstances);

        // Invalidate current key, because it cannot be used again (side-channel
        // attacks).
        sgxRegistry[instanceId] = InstanceData(newAddress, uint64(block.timestamp));
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

        // Size is: 85 bytes
        // 20 bytes + 65 bytes (signature) = 85
        if (evidence.proof.length != 85) {
            revert SGX_INVALID_PROOF_SIZE();
        }

        uint16 instanceId =
            uint16(bytes2(LibBytesUtils.slice(evidence.proof, 0, 2)));

        address newInstance =
            address(bytes20(LibBytesUtils.slice(evidence.proof, 2, 20)));

        bytes memory signature = LibBytesUtils.slice(evidence.proof, 22);

        address oldInstance =
            getSignedHash(evidence, prover, newInstance).recover(signature);

        if (!isInstanceValid(instanceId, oldInstance)) {
            revert SGX_INSTANCE_INVALID();
        }

        // Invalidate current key, because it cannot be used again (side-channel
        // attacks).
        sgxRegistry[instanceId] = InstanceData(newInstance, uint64(block.timestamp));

        emit InstanceChanged(instanceId, oldInstance, newInstance, uint64(block.timestamp));
    }

    function getSignedHash(
        TaikoData.BlockEvidence memory evidence,
        address prover,
        address newAddress
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
                prover,
                newAddress
            )
        );
    }

    function isInstanceValid(
        uint256 instanceId,
        address instance
    )
        internal
        view
        returns (bool)
    {
        return (sgxRegistry[instanceId].activeAddress == instance && sgxRegistry[instanceId].effectiveSince + INSTANCE_EXPIRY > block.timestamp);
    }

    function addTrustedInstances(address[] memory trustedInstances) internal {
        for (uint256 i; i < trustedInstances.length; i++) {
            sgxRegistry[uniqueVerifiers] = InstanceData(trustedInstances[i], uint64(block.timestamp));

            emit InstanceAdded(uniqueVerifiers, trustedInstances[i], uint64(block.timestamp));

            uniqueVerifiers++;
        }
    }
}

/// @title ProxiedSgxVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxVerifier is Proxied, SgxVerifier { }
