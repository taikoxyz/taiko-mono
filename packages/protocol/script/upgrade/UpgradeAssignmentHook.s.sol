// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/hooks/AssignmentHook.sol";
import "./UpgradeScript.s.sol";

contract UpgradeAssignmentHook is UpgradeScript {
    function run() external setUp {
        upgrade("AssignmentHook", address(new AssignmentHook()));
    }
}
