// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoL2} from "../../L2/TaikoL2.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

contract TestTaikoL2 is TaikoL2 {
    constructor(address _addressManager) TaikoL2(_addressManager) {}
}
