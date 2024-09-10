// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/layer1/team/proving/ProverSet.sol";
import "./UpgradeScript.s.sol";

contract UpgradeProverSet is UpgradeScript {
    function run() external setUp {
        upgrade("ProverSet", address(new ProverSet()));
    }
}
