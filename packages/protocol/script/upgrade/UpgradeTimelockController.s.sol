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

pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/gov/TaikoTimelockController.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoTimelockController is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading TaikoTimelockController");
        TaikoTimelockController newTaikoTimelockController = new TaikoTimelockController();
        upgrade(address(newTaikoTimelockController));

        console2.log("upgraded TaikoTimelockController to", address(newTaikoTimelockController));
    }
}
