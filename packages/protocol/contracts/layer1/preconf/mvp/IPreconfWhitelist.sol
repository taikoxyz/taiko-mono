// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPreconfWhitelist {
    /**
     * @dev Checks if a given address is eligible to propose.
     * @param _proposer The address to check.
     * @return bool indicating if the address is whitelisted.
     */
    function isEligibleProposer(address _proposer) external view returns (bool);

    /**
     * @dev Registers a proposer to the whitelist. Can only be called by the owner.
     * @param _proposer The address to be whitelisted.
     */
    function registerProposer(address _proposer) external;

    /**
     * @dev Deregisters a proposer from the whitelist. Can only be called by the owner.
     * @param _proposer The address to be removed from the whitelist.
     */
    function deregisterProposer(address _proposer) external;

    /**
     * @dev Returns the list of whitelisted addresses.
     * @return An array of whitelisted addresses.
     */
    function getWhitelist() external view returns (address[] memory);
}
