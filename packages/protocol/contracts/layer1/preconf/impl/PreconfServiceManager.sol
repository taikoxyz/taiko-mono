// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/IPreconfServiceManager.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract PreconfServiceManager is IPreconfServiceManager, EssentialContract {
    function slashOperator(address operator) external {
        // TODO
    }
}
