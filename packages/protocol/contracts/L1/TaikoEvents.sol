// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoData} from "./TaikoData.sol";
import {SyncData} from "../common/IHeaderSync.sol";

abstract contract TaikoEvents {
    // The following events must match the definitions in other V1 libraries.
    event BlockVerified(uint256 indexed id, SyncData syncData);

    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        TaikoData.ForkChoice forkChoice
    );
}
