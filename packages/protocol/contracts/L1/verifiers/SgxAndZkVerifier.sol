// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibBytesUtils } from "../../thirdparty/LibBytesUtils.sol";
import { Proxied } from "../../common/Proxied.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice See the documentation in {IVerifier}.
contract SgxAndZkVerifier is EssentialContract, IVerifier {
    uint8 public constant SGX_PROOF_SIZE = 87;
    uint256[50] private __gap;

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        uint64 blockId,
        address prover,
        bool isContesting,
        bytes32 blobVersionHash,
        TaikoData.BlockEvidence calldata evidence
    )
        external
    {
        TaikoData.BlockEvidence memory _evidence = evidence;

        // Verify the SGX part
        _evidence.proof = LibBytesUtils.slice(evidence.proof, 0, SGX_PROOF_SIZE);
        IVerifier(resolve("tier_sgx", false)).verifyProof(
            blockId, prover, isContesting, blobVersionHash, _evidence
        );

        // Verify the ZK part
        _evidence.proof = LibBytesUtils.slice(
            evidence.proof,
            SGX_PROOF_SIZE,
            (evidence.proof.length - SGX_PROOF_SIZE)
        );
        IVerifier(resolve("tier_pse_zkevm", false)).verifyProof(
            blockId, prover, isContesting, blobVersionHash, _evidence
        );
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxAndZkVerifier is Proxied, SgxAndZkVerifier { }
