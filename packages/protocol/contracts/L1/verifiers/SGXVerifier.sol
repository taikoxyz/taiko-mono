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

/// @title SGXVerifier
contract SGXVerifier is EssentialContract, IVerifier {
    using ECDSAUpgradeable for bytes32;

    uint256 public constant INSTANCE_EXPIRY = 180 days;

    mapping(address instance => uint256 registeredAt) public instances;

    uint256[49] private __gap;

    event InstanceRegistered(
        address indexed replaced, address indexed instance, uint256 registeredAt
    );

    error SGX_INVALID_AUTH();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_PROOF_SIZE();
    error SGX_INSTANCE_REGISTERED();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param trustedInstances The address array of trusted SGX instances.
    function registerInstance(address[] memory trustedInstances)
        external
        onlyOwner
    {
        for (uint256 i; i < trustedInstances.length; i++) {
            _replaceInstance(address(0), trustedInstances[i]);
        }
    }

    /// @notice Removes trusted SGX instances from the registry.
    /// @param oldInstance The address of a compromised SGX instance.
    function invalidateInstance(address oldInstance) external onlyOwner {
        instances[oldInstance] = 1;
    }

    /// @notice Adds trusted SGX instances to the registry by another SGX
    /// instance.
    /// @param newAddress The new address of the instance.
    /// @param trustedInstances The address array of trusted SGX instances.
    /// @param signature The signature proving authenticity.
    function registerBySgxInstance(
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

        for (uint256 i; i < trustedInstances.length; i++) {
            _replaceInstance(address(0), trustedInstances[i]);
        }

        _replaceInstance(signer, newAddress);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
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

        address newInstance =
            address(bytes20(LibBytesUtils.slice(evidence.proof, 0, 20)));

        bytes memory signature = LibBytesUtils.slice(evidence.proof, 20);

        address oldInstance =
            getSignedHash(evidence, prover, newInstance).recover(signature);

        _replaceInstance(oldInstance, newInstance);
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

    function isInstanceValid(address instance) public view returns (bool) {
        return instances[instance] + INSTANCE_EXPIRY > block.timestamp;
    }

    function _replaceInstance(
        address oldInstance,
        address newInstance
    )
        private
    {
        if (oldInstance != address(0)) {
            if (!isInstanceValid(oldInstance)) revert SGX_INVALID_AUTH();
            instances[oldInstance] = 1;
        }

        if (newInstance == address(0)) revert SGX_INVALID_INSTANCE();
        if (instances[newInstance] != 0) revert SGX_INSTANCE_REGISTERED();

        instances[newInstance] = block.timestamp;
        emit InstanceRegistered(oldInstance, newInstance, block.timestamp);
    }
}

/// @title ProxiedSGXVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSGXVerifier is Proxied, SGXVerifier { }
