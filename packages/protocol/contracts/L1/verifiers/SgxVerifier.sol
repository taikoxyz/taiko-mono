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

/// @title SgxVerifier
contract SgxVerifier is EssentialContract, IVerifier {
    using ECDSAUpgradeable for bytes32;

    uint256 public constant INSTANCE_EXPIRY = 180 days;

    event InstanceAdded(
        uint256 indexed id,
        address indexed instance,
        address replaced,
        uint64 timstamp
    );

    struct Instance {
        address addr;
        uint64 addedAt; // We can calculate if expired
    }

    /// @dev For gas savings, we shall assign each SGX instance with an id
    /// so that when we need to set a new pub key, just write storage once.
    uint256 public numInstances; // slot 1

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA
    /// public key (or rather ethereum address). Once that address is used (by
    /// proof verification) it has to be overwritten by a new one (representing
    /// the same instance). This is due to side-channel protection. Also this
    /// public key shall expire after some time. (For now it is a long enough 6
    /// months setting.)
    mapping(uint256 instanceId => Instance) public instances; // slot 2

    uint256[48] private __gap;

    error SGX_INVALID_PROOF_SIZE();
    error SGX_INVALID_INSTANCE();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param _instances The address array of trusted SGX instances.
    function addInstances(address[] calldata _instances) external onlyOwner {
        _addInstances(_instances);
    }

    /// @notice Adds trusted SGX instances to the registry by another SGX
    /// instance.
    /// @param id The id of the SGX instance who is adding new members.
    /// @param newAddress The new address of the instance.
    /// @param _instances The address array of trusted SGX instances.
    /// @param signature The signature proving authenticity.
    function addInstancesBySgx(
        uint256 id,
        address newAddress,
        address[] calldata _instances,
        bytes calldata signature
    )
        external
    {
        bytes32 signedHash = keccak256(
            abi.encode("REGISTER_SGX_INSTANCE", newAddress, _instances)
        );
        // Would throw in case invalid
        address signer = signedHash.recover(signature);

        if (!isInstanceValid(id, signer)) {
            revert SGX_INVALID_INSTANCE();
        }

        // Allow user to add
        _addInstances(_instances);

        // Exchange this id's address
        _replaceInstance(id, signer, newAddress);
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

        // Size is: 87 bytes
        // 2 bytes + 20 bytes + 65 bytes (signature) = 87
        if (evidence.proof.length != 87) {
            revert SGX_INVALID_PROOF_SIZE();
        }

        uint16 id = uint16(bytes2(LibBytesUtils.slice(evidence.proof, 0, 2)));

        address newInstance =
            address(bytes20(LibBytesUtils.slice(evidence.proof, 2, 20)));

        bytes memory signature = LibBytesUtils.slice(evidence.proof, 22);

        address oldInstance =
            getSignedHash(evidence, prover, newInstance).recover(signature);

        if (!isInstanceValid(id, oldInstance)) {
            revert SGX_INVALID_INSTANCE();
        }

        _replaceInstance(id, oldInstance, newInstance);
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
        uint256 id,
        address instance
    )
        internal
        view
        returns (bool)
    {
        return (
            instances[id].addr == instance
                && instances[id].addedAt + INSTANCE_EXPIRY > block.timestamp
        );
    }

    function _addInstances(address[] calldata _instances) private {
        for (uint256 i; i < _instances.length; i++) {
            instances[numInstances] =
                Instance(_instances[i], uint64(block.timestamp));

            emit InstanceAdded(
                numInstances, _instances[i], address(0), uint64(block.timestamp)
            );

            numInstances++;
        }
    }

    function _replaceInstance(
        uint256 id,
        address oldInstance,
        address newInstance
    )
        private
    {
        // Invalidate current key, because it cannot be used again (side-channel
        // attacks).
        instances[id] = Instance(newInstance, uint64(block.timestamp));

        emit InstanceAdded(
            id, newInstance, oldInstance, uint64(block.timestamp)
        );
    }
}

/// @title ProxiedSgxVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxVerifier is Proxied, SgxVerifier { }
