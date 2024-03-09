// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/verifiers/GuardianVerifier.sol";
import "./UpgradeScript.s.sol";

contract UpgradeGuardianVerifier is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading GuardianVerifier");
        GuardianVerifier newGuardianVerifier = new GuardianVerifier();
        upgrade(address(newGuardianVerifier));

        console2.log("upgraded GuardianVerifier to", address(newGuardianVerifier));
    }
}
