// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IAddressManager.sol";
import "./IAddressResolver.sol";

/// @title AddressResolver
/// @notice See the documentation in {IAddressResolver}.
/// @custom:security-contact security@taiko.xyz
abstract contract AddressResolver is IAddressResolver, Initializable {
    /// @notice Address of the AddressManager.
    address public addressManager;
    uint256[49] private __gap;


}
