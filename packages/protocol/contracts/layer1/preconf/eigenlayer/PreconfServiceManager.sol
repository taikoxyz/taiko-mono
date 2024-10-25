// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../iface/IPreconfServiceManager.sol";

/// @notice An implementation of IPreconfServiceManager on top of Eigenlayer restaking.
abstract contract PreconfServiceManager is IPreconfServiceManager, ReentrancyGuard { }
