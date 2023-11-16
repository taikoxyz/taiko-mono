// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";

import { TaikoData } from "../TaikoData.sol";

import { IVerifier } from "./IVerifier.sol";

/// @title GuardianVerifier
contract GuardianVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error PERMISSION_DENIED();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The initial owner
    /// @param _addressManager The address of the address manager contract.
    function init(
        address _owner,
        address _addressManager
    )
        external
        initializer
    {
        EssentialContract._init(_owner, _addressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata ctx,
        TaikoData.Transition calldata,
        TaikoData.TierProof calldata
    )
        external
        view
    {
        if (ctx.prover != resolve("guardian_prover", false)) {
            revert PERMISSION_DENIED();
        }
    }
}
