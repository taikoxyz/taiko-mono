// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "./ForkRouter_Layout.sol"; // DO NOT DELETE

/// @title ForkRouter
/// @notice Routes calls between the legacy and new fork implementations using delegatecall.
///
///                         +--> newFork
/// PROXY -> FORK_ROUTER--|
///                         +--> oldFork
///
/// @dev WARNING: This contract uses 151 slots [0..150]. Routed contracts should reserve 151 slots
/// to avoid collisions. This is because calls are made via `delegatecall`, which means they this
/// and the routed contract share the same storage.
/// @custom:security-contact security@taiko.xyz
abstract contract ForkRouter is UUPSUpgradeable, Ownable2StepUpgradeable {
    address public immutable oldFork;
    address public immutable newFork;

    error InvalidParams();
    error ZeroForkAddress();

    constructor(address _oldFork, address _newFork) {
        require(_newFork != address(0), InvalidParams());
        require(_newFork != _oldFork, InvalidParams());

        oldFork = _oldFork;
        newFork = _newFork;

        _disableInitializers();
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    /// @notice Returns true if a function should be routed to the old fork implementation.
    /// @dev Override to provide fork-specific routing logic.
    function shouldRouteToOldFork(bytes4) public view virtual returns (bool);

    function _fallback() internal virtual {
        address fork = shouldRouteToOldFork(msg.sig) ? oldFork : newFork;
        require(fork != address(0), ZeroForkAddress());

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), fork, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
