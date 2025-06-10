// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title EmptyImpl
 * @notice Empty implementation contract that can be used as a temporary proxy implementation
 * @dev This contract is meant to be used as a placeholder implementation that can be upgraded later
 */
contract EmptyImpl is UUPSUpgradeable, OwnableUpgradeable {
    // Empty implementation - all function calls will revert
    // This is intentional as it's meant to be a temporary placeholder
    // This safe since UUPSUpgradeable uses unique slot to store implementation address

    /**
     * @dev Function that authorizes the upgrade. Since this is an empty implementation,
     * we allow any address to upgrade to prevent the proxy from being stuck.
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        // Allow any address to upgrade since this is just a temporary implementation
        // In a production environment, this should be restricted to authorized addresses
    }

    /**
     * @dev Function that can be used to externally check if the implementation is empty.
     */
    function isEmptyImpl() external pure returns (bool) {
        return true;
    }
}
