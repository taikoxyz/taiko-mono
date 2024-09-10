// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "./UpgradeScript.s.sol";
import "../../contracts/layer1/verifiers/Risc0Verifier.sol";

contract UpgradeRisc0Verifier is UpgradeScript {
    function run() external setUp {
        upgrade("Risc0Verifier", address(new Risc0Verifier()));
    }
}
