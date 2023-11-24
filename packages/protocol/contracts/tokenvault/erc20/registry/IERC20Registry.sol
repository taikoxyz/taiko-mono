// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IERC20Registry
interface IERC20Registry {
    // There might be different burn function signatures like:
    // 'function burn(address from, uint256 amunt)'
    // Currently USDC is the only one we are trying to support.
    // isCustomToken in the return value can indicate which is the correct burn function signature.
    function burn(uint256 amount) external;

    function getCustomCounterPart(address l1Address) external view returns (address);

    function getCanonicalAndBurnSignature(address l2Address)
        external
        view
        returns (address, uint8);
}
