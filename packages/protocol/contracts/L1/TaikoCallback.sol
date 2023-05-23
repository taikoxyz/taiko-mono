// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoData} from "./TaikoData.sol";

/// @custom:security-contact hello@taiko.xyz
interface TaikoCallback {
    function afterBlockProposed(address proposer, TaikoData.BlockMetadata memory meta) external;
    function afterBlockVerified(address prover, uint64 proposedAt, uint64 provenAt) external;
}
