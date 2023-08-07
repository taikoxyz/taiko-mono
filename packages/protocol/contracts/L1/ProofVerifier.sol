// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibZKPVerifier } from "./libs/verifiers/LibZKPVerifier.sol";
import { IProofVerifier } from "./IProofVerifier.sol";
import { LibBytesUtils } from "../thirdparty/LibBytesUtils.sol";

/**
 * @title ProofVerifier
 * @dev Contract for verifying proofs in the rollup.
 */
contract ProofVerifier is EssentialContract, IProofVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    /**
     * @notice Initializes the contract with the provided address manager.
     * @param _addressManager The address of the address manager contract.
     */
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /**
     * @notice Verifies the provided proofs.
     * @dev Throws an error if verification fails.
     *
     * @param blockProofs Raw bytes of proof(s).
     * @param instance Hashed evidence & config data. If set to zero, proof is
     * assumed to be from oracle/system prover.
     */
    function verifyProofs(
        uint256, /*blockId*/
        bytes calldata blockProofs,
        bytes32 instance
    )
        external
        view
    {
        // If instance is zero, proof is considered as from oracle/system prover
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
        LibZKPVerifier.verifyProof(
            AddressResolver(address(this)), blockProofs[2:], verifierId
        );
    }
}

/**
 * @title ProxiedProofVerifier
 * @dev Proxied version of the ProofVerifier contract.
 */
contract ProxiedProofVerifier is Proxied, ProofVerifier { }
