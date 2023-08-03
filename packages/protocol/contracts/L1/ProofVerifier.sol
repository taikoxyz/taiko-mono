// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibVerifyZKP } from "./libs/proofTypes/LibVerifyZKP.sol";
import { IProofVerifier } from "./IProofVerifier.sol";
import { LibBytesUtils } from "../thirdparty/LibBytesUtils.sol";

/// @custom:security-contact hello@taiko.xyz
contract ProofVerifier is EssentialContract, IProofVerifier {
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /**
     * Verifying proofs
     *
     * @param blockProofs Raw bytes of proof(s)
     */
    function verifyProofs(
        uint256, //Can be used later when supporting different types of proofs
        bytes calldata blockProofs,
        bytes32 instance
    )
        external
        view
    {
        // Not checked if oracle/system prover
        if (instance == 0) return;

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

        uint16 verifierId = uint16(bytes2(blockProofs[0:2]));

        // Verify ZK proof
        LibVerifyZKP.verifyProof(
            AddressResolver(address(this)), blockProofs[2:], verifierId
        );
    }
}

contract ProxiedProofVerifier is Proxied, ProofVerifier { }
