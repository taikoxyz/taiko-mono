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

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(
        address _owner,
        address _addressManager
    )
        external
        initializer
        initEssential(_owner, _addressManager)
    { }

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
