// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/provers/GuardianProver.sol";
import "./UpgradeScript.s.sol";

contract UpgradeGuardianProver is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading GuardianProver");
        GuardianProver newGuardianProver = new GuardianProver();
        upgrade(address(newGuardianProver));

        console2.log("upgraded GuardianProver to", address(newGuardianProver));
    }
}
