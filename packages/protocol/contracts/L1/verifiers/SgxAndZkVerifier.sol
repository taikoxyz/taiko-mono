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
    uint8 public constant SGX_PROOF_SIZE = 224;
    uint256[50] private __gap;

    error L1_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
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

        bytes memory sgxBytes = LibBytesUtils.slice(evidence.proof, 0, SGX_PROOF_SIZE);
        bytes memory zkProofBytes = LibBytesUtils.slice(evidence.proof, SGX_PROOF_SIZE, (evidence.proof.length - SGX_PROOF_SIZE));

        TaikoData.BlockEvidence memory mEvidence = evidence;
        
        // Verify the ZK part
        mEvidence.proof = zkProofBytes;
        IVerifier(resolve("tier_pse_zkevm", true)).verifyProof(0, prover, false, mEvidence);

        // Verify the SGX part
        mEvidence.proof = sgxBytes;
        IVerifier(resolve("tier_sgx", true)).verifyProof(0, prover, false, mEvidence);
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxAndZkVerifier is Proxied, SgxAndZkVerifier { }
