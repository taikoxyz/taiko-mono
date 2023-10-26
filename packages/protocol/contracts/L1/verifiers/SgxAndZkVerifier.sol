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
        Context calldata ctx,
        TaikoData.TransitionClaim calldata claim,
        TaikoData.TierProof calldata tproof
    )
        external
    {
        TaikoData.TierProof memory _tproof;
        _tproof.tier = tproof.tier;

        // Verify the SGX part
        _tproof.data = LibBytesUtils.slice(tproof.data, 0, SGX_PROOF_SIZE);
        IVerifier(resolve("tier_sgx", false)).verifyProof(ctx, claim, _tproof);

        // Verify the ZK part
        _tproof.data = LibBytesUtils.slice(
            tproof.data, SGX_PROOF_SIZE, (tproof.data.length - SGX_PROOF_SIZE)
        );
        IVerifier(resolve("tier_pse_zkevm", false)).verifyProof(
            ctx, claim, _tproof
        );
    }
}

/// @title ProxiedProofVerifier
/// @notice Proxied version of the parent contract.
contract ProxiedSgxAndZkVerifier is Proxied, SgxAndZkVerifier { }
