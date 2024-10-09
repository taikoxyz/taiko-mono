// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/LibNames.sol";

/// @title PreconfServiceManager
/// @custom:security-contact security@taiko.xyz
contract PreconfServiceManager is IPreconfServiceManager, EssentialContract {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @inheritdoc IPreconfServiceManager
    function slashOperator(address _operator)
        external
        onlyFromNamed(LibNames.B_PRECONF_TASK_MANAGER)
    {
        // TODO
    }

    /// @inheritdoc IPreconfServiceManager
    function lockStakeUntil(
        address _operator,
        uint256 _timestamp
    )
        external
        nonReentrant
        onlyFromNamed(LibNames.B_PRECONF_TASK_MANAGER)
    {
        // TODO
    }
}
