// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../bridge/Bridge.sol";

contract TestBridge is Bridge {
    error InvalidProcessMessageGasLimit(uint256 provided, uint256 minimum);

    function hack() public {
        revert InvalidProcessMessageGasLimit(0, 1);
    }
}
