// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../TaikoData.sol";

/// @title IHook Interface
interface IHook {
    function onBlockProposed(
        TaikoData.Block memory blk,
        TaikoData.BlockMetadata memory meta,
        bytes memory data
    )
        external
        payable;
}
