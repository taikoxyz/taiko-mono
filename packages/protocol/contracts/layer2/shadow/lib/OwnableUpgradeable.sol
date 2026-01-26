// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact security@taiko.xyz

abstract contract OwnableUpgradeable is Ownable2StepUpgradeable, UUPSUpgradeable {
    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    function __OwnableUpgradeable_init(address _owner) internal onlyInitializing {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        _transferOwnership(_owner);
    }

    /// @notice Initializes the contract with caller as owner.
    function _initialize() internal initializer {
        __OwnableUpgradeable_init(msg.sender);
    }

    /// @dev Authorizes an upgrade to a new implementation.
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
