// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../iface/IPreconfServiceManager.sol";

/// @title PreconfServiceManager
/// @dev An implementation of IPreconfServiceManager on top of Eigenlayer restaking.
/// @custom:security-contact security@taiko.xyz
abstract contract PreconfServiceManager is IPreconfServiceManager, ReentrancyGuard { }
