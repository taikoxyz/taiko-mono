// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {SignalService} from "../../signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract TestSignalService is SignalService {
    // The old implementation that is also used in hardhat tests.
    function keyForName(
        uint256 chainId,
        string memory name
    ) public pure override returns (string memory key) {
        key = string.concat(Strings.toString(chainId), ".", name);
    }
}
