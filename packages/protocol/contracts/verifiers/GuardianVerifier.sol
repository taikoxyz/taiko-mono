// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../L1/TaikoData.sol";
import "./IVerifier.sol";

/// @title GuardianVerifier
contract GuardianVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error PERMISSION_DENIED();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
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
        if (ctx.msgSender != resolve("guardian_prover", false)) {
            revert PERMISSION_DENIED();
        }
    }
}
