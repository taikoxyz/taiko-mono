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

    event InstancesChanged();

    struct Instance {
        address addr;
        uint64 effectiveSince;
    }

    Instance[] public instances;
    // mapping(address instance => uint256 registeredAt) public instances;

    uint256[49] private __gap;

    error SGX_INVALID_AUTH();
    error SGX_INVALID_ID();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_PROOF_SIZE();
    error SGX_INSTANCE_EXPIRED();

    modifier onlyValidId(uint256 id) {
        if (!_isIdValid(id)) revert SGX_INVALID_ID();
        _;
    }

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param instance The address of a new SGX instances.
    function addInstance(address instance) external onlyOwner {
        _addInstance(instance);
        emit InstancesChanged();
    }

    /// @notice Removes trusted SGX instances from the registry.
    /// @param id The Id of the instance to remove.
    function removeInstance(uint256 id) external onlyOwner onlyValidId(id) {
        _removeInstance(id);
        emit InstancesChanged();
    }

    /// @notice Adds trusted SGX instances to the registry by another SGX
    /// instance.
    /// @param newInstances The address array of trusted SGX instances.
    /// @param signature The signature proving authenticity.
    function addInstanceBySgx(
        uint256 id,
        bytes memory signature,
        address[] memory newInstances
    )
        external
        onlyValidId(id)
    {
        if (
            instances[id - 1].effectiveSince + INSTANCE_EXPIRY
                >= block.timestamp
        ) revert SGX_INSTANCE_EXPIRED();

        bytes32 hash = keccak256(abi.encode("ADD_NEW_INSTANCES", newInstances));
        // Would throw in case invalid
        if (instances[id].addr != hash.recover(signature)) {
            revert SGX_INVALID_AUTH();
        }

        _removeInstance(id);
        for (uint256 i; i < newInstances.length; ++i) {
            _addInstance(newInstances[i]);
        }

        emit InstancesChanged();
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        uint64 blockId,
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

        uint64 id = 0; // TODO

        if (!_isIdValid(id)) revert SGX_INVALID_ID();
        if (!_isExpired(instances[id - 1].effectiveSince)) {
            revert SGX_INSTANCE_EXPIRED();
        }

        address newInstance =
            address(bytes20(LibBytesUtils.slice(evidence.proof, 0, 20)));
        bytes memory signature = LibBytesUtils.slice(evidence.proof, 20);
        bytes32 hash = getSignedHash(blockId, evidence, prover, newInstance);

        if (instances[id].addr != hash.recover(signature)) {
            revert SGX_INVALID_AUTH();
        }
        _removeInstance(id);
        _addInstance(newInstance);
        emit InstancesChanged();
    }

    function getSignedHash(
        uint64 blockId,
        TaikoData.BlockEvidence memory evidence,
        address prover,
        address newInstance
    )
        public
        pure
        returns (bytes32 signedHash)
    {
        return keccak256(
            abi.encode(
                blockId,
                evidence.metaHash,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                evidence.graffiti,
                prover,
                newInstance
            )
        );
    }

    function _isIdValid(uint256 id) private view returns (bool) {
        return id > 0 && id <= instances.length;
    }

    function _addInstance(address instance) private {
        if (instance == address(0)) revert SGX_INVALID_INSTANCE();
        instances.push(Instance(instance, uint64(block.timestamp)));
    }

    function _removeInstance(uint256 id) private onlyValidId(id) {
        // purge up to 10 instances
        for (uint256 i; i < 10; ++i) {
            Instance memory last = instances[instances.length - 1];
            if (_isExpired(last.effectiveSince)) instances.pop();
            else break;
        }

        if (id != instances.length) {
            // Move the last element to the emply slot
            Instance memory last = instances[instances.length - 1];
            instances[id - 1] = last;
        }
        instances.pop();
    }

    function _isExpired(uint64 effectiveSince) private view returns (bool) {
        return effectiveSince + INSTANCE_EXPIRY <= block.timestamp;
    }
}

/// @title ProxiedSgxVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxVerifier is Proxied, SgxVerifier { }
