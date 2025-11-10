// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/shared/governance/TaikoTokenTransferHelper.sol";

contract DeployTaikoTokenTransferHelper is BaseScript {
    function run() external broadcast {
        address helper = address(new TaikoTokenTransferHelper());
        console2.log("TaikoTokenTransferHelper deployed at:", helper);
    }
}
