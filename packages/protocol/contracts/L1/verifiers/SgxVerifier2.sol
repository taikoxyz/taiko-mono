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

/// @title SgxVerifier2
contract SgxVerifier2 is EssentialContract, IVerifier {
    using ECDSAUpgradeable for bytes32;

    uint256 public constant INSTANCE_EXPIRY = 180 days;

    event InstanceRegistered(
        address indexed replaced, address indexed instance, uint256 registeredAt
    );

    // struct InstanceData {
    //     address activeAddress;
    //     uint256 setAt; // We can calculate if expired
    // }

    /// @dev For gas savings, we shall assign each SGX instance with an id
    /// so that when we need to set a new pub key, just write storage once.
    // uint256 public uniqueVerifiers;

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA
    /// public key (or rather ethereum address). Once that address is used (by
    /// proof verification) it has to be overwritten by a new one (representing
    /// the same instance). This is due to side-channel protection. Also this
    /// public key shall expire after some time. (For now it is a long enough 6
    /// months setting.)
    // mapping(uint256 instanceId => InstanceData sgxInstance) public
    // sgxRegistry;
    mapping(address instance => uint256 registeredAt) instances;

    uint256[49] private __gap;

    error SGX_INVALID_AUTH();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_PROOF_SIZE();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function registerInstance(address instance) external onlyOwner {
        _replaceInstance(address(0), instance);
    }

    // TODO(dani): who will call this function?
    function replaceInstance(
        address newInstance,
        bytes memory signature
    )
        external
    {
        address oldInstance = keccak256(
            abi.encode("REGISTER_SGX_INSTANCE", newInstance)
        ).recover(signature);

        _replaceInstance(oldInstance, newInstance);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        uint64,
        address prover,
        bool isContesting,
        TaikoData.BlockEvidence calldata evidence
    )
        external
        onlyFromNamed("taiko")
    {
        // Do not run proof verification to contest an existing proof
        if (isContesting) return;

        // Size is: 87 bytes
        // 2 bytes + 20 bytes + 65 bytes = 87
        if (evidence.proof.length <= 20) {
            revert SGX_INVALID_PROOF_SIZE();
        }

        address newInstance =
            address(bytes20(LibBytesUtils.slice(evidence.proof, 0, 20)));

        bytes memory signature = LibBytesUtils.slice(evidence.proof, 20);

        address oldInstance =
            getSignedHash(evidence, prover, newInstance).recover(signature);

        _replaceInstance(oldInstance, newInstance);
    }

    function isInstanceValid(address instance) public view returns (bool) {
        return instances[instance] != 0
            && instances[instance] + INSTANCE_EXPIRY > block.timestamp;
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

    function _replaceInstance(
        address oldInstance,
        address newInstance
    )
        private
    {
        if (oldInstance != address(0)) {
            if (!isInstanceValid(oldInstance)) revert SGX_INVALID_AUTH();
            delete instances[oldInstance];
        }

        if (newInstance == address(0)) revert SGX_INVALID_INSTANCE();
        instances[newInstance] = block.timestamp;
        emit InstanceRegistered(oldInstance, newInstance, block.timestamp);
    }
}

/// @title ProxiedSgxVerifier2
/// @notice Proxied version of the parent contract.
contract ProxiedSgxVerifier2 is Proxied, SgxVerifier2 { }
