// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibVerifyZKP } from "./libs/proofTypes/LibVerifyZKP.sol";
import { IProofVerifier } from "./IProofVerifier.sol";

/// @custom:security-contact hello@taiko.xyz
contract ProofVerifier is EssentialContract, IProofVerifier {

    // Because we omit the 'TypedProof' struct on the abi.encode() side
    // (in LibProving.sol - we dont introduce new structs), when we want 
    // to decode the data in struct we need to prepend the struct encoding.
    // This helps NOW and might be helpful later when we generalizing the
    // proof bytes (if we have more, like SGX, Oracle, etc.) - so that we
    // dont need to have custom structs in the core protocol just raw bytes.
    bytes structEncoding = hex'0000000000000000000000000000000000000000000000000000000000000020';
    
    // This is just for "later on" when we will support multiple
    // proof types (e.g.: SGX), we can decode the raw bytes.
    struct TypedProof {
        uint16 verifierId; // This one when get abi.encoded gets a full slot
        bytes32 proofType;
        bytes proof;
    }

    uint256[50] private __gap;

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function verifyProofs(
        bytes calldata blockProofs
    )
    external
    view
    {
        TypedProof memory decodedData = abi.decode(
            abi.encode(
                structEncoding,
                blockProofs
            ), 
            (TypedProof)
        );
        // If we dont use that structEncoding we would need to unpack/decode variables like this:
        //(uint16 verifierId, bytes32 proofType, bytes memory proof) = abi.decode(blockProofs, (uint16, bytes32, bytes));

        // Again, later it is a for() until proofs.length()
        if (decodedData.proofType == keccak256("ZK")){
            LibVerifyZKP.verifyProof(
                AddressResolver(address(this)),
                decodedData.proof,
                decodedData.verifierId
            );
        }
        // else if (decodedData.proofType == keccak256("SGX"))
        // etc.
    }
}

contract ProxiedProofVerifier is Proxied, ProofVerifier {}
