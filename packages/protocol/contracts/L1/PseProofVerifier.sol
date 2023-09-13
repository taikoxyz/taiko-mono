// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { LibBytesUtils } from "../thirdparty/LibBytesUtils.sol";
import { LibUtils } from "./libs/LibUtils.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title IPseProofVerifier
/// @notice Contract that is responsible for verifying proofs.
interface IPseProofVerifier {
    /// @notice Verify the given proof(s) for the given blockId. This function
    /// should revert if the verification fails.
    /// @param blockId Unique identifier for the block.
    /// @param blockProofs Raw bytes representing the proof(s).
    /// @param instance Hashed evidence & config data. If set to zero, proof is
    /// assumed to be from oracle prover.
    function verifyProofs(
        uint64 blockId,
        bytes calldata blockProofs,
        bytes32 instance
    )
        external;
}

/// @title PseProofVerifier
/// @notice See the documentation in {IPseProofVerifier}.
contract PseProofVerifier is EssentialContract, IPseProofVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc IPseProofVerifier
    function verifyProofs(
        // blockId is unused now, but can be used later when supporting
        // different types of proofs.
        uint64,
        bytes calldata blockProofs,
        bytes32 instance
    )
        external
        view
    {
        // If instance is zero, proof is considered as from oracle prover
        // and not checked.
        if (instance == 0) return;

        // Validate the instance using bytes utilities.
        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(blockProofs, 2, 32),
                bytes.concat(bytes16(0), bytes16(instance))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        if (
            !LibBytesUtils.equal(
                LibBytesUtils.slice(blockProofs, 34, 32),
                bytes.concat(bytes16(0), bytes16(uint128(uint256(instance))))
            )
        ) {
            revert L1_INVALID_PROOF();
        }

        // Extract verifier ID from the proof.
        uint16 verifierId = uint16(bytes2(blockProofs[0:2]));

        // Delegate to the ZKP verifier library to validate the proof.
        _verify(AddressResolver(address(this)), blockProofs[2:], verifierId);
    }

    function _verify(
        AddressResolver resolver,
        bytes memory proof,
        uint16 verifierId
    )
        private
        view
    {
        // Resolve the verifier's name and obtain its address.
        address verifierAddress =
            resolver.resolve(LibUtils.getVerifierName(verifierId), false);

        // Call the verifier contract with the provided proof.
        (bool verified, bytes memory ret) =
            verifierAddress.staticcall(bytes.concat(proof));

        // Check if the proof is valid.
        if (!verified || ret.length != 32 || bytes32(ret) != keccak256("taiko"))
        {
            revert L1_INVALID_PROOF();
        }
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedPseProofVerifier is Proxied, PseProofVerifier { }
