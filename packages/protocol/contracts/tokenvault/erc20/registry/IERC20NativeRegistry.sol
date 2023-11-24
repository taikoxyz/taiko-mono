// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IERC20NativeRegistry
interface IERC20NativeRegistry {
    function getPredeployedAndTranslator(address l1Address)
        external
        view
        returns (address, address);

    function getCanonicalAndTranslator(address l2Address)
        external
        view
        returns (address, address);
}
