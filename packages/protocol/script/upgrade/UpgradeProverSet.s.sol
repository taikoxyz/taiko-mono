// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/team/proving/ProverSet.sol";
import "./UpgradeScript.s.sol";

contract UpgradeProverSet is UpgradeScript {
    function run() external setUp {
        upgrade("ProverSet", address(new ProverSet()));
    }
}
