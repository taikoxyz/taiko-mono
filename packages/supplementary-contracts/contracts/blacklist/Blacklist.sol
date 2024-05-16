// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./IMinimalBlacklist.sol";

/**
 * @title Blacklist
 * @dev List of blacklisted addresses on Ethereum
 * @dev Source: https://etherscan.io/address/0x97044531D0fD5B84438499A49629488105Dc58e6#readContract
 */
contract Blacklist is IMinimalBlacklist, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice We use a mapping in addition to an EnumerableSet to make reading from the storage
    /// addresses easier
    // solhint-disable-next-line named-parameters-mapping
    mapping(address => bool) public isBlacklisted;

    /// @notice We use an EnumerableSet to make lookups and iteration easier
    // solhint-disable-next-line state-visibility
    EnumerableSet.AddressSet blacklistSet;

    /// @notice Permissioned role able to add and remove addresses from the blacklist
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    /// @notice Only Updater modifier
    modifier onlyUpdater() {
        // solhint-disable-next-line gas-custom-errors
        require(hasRole(UPDATER_ROLE, msg.sender), "Must be updater");
        _;
    }

    /// @notice Event emitted when an address is added to the blacklist
    event Blacklisted(address indexed _account);

    /// @notice Event emitted when an address is removed from the blacklist
    event UnBlacklisted(address indexed _account);

    /**
     * @notice Construct a new Blacklist contract
     * @param _admin Blacklist admin
     * @param _updater Initial updater address
     * @param _blacklist Initial blacklist
     */
    constructor(address _admin, address _updater, address[] memory _blacklist) {
        _setupRole(UPDATER_ROLE, _updater);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _addToBlacklist(_blacklist);
    }

    /**
     * @notice Add addresses to the blacklist
     * @param newBlacklistEntries Addresses to add to the blacklist
     */
    function addToBlacklist(address[] calldata newBlacklistEntries) external onlyUpdater {
        _addToBlacklist(newBlacklistEntries);
    }

    /**
     * @notice Remove addresses from the blacklist
     * @param blacklistEntriesToRemove Addresses to remove from the blacklist
     */
    function removeFromBlacklist(address[] calldata blacklistEntriesToRemove)
        external
        onlyUpdater
    {
        _removeFromBlacklist(blacklistEntriesToRemove);
    }

    /**
     * @notice Add and remove addresses from the blacklist in a single transaction
     * @param addressesToAdd Addresses to add to the blacklist
     * @param addressesToRemove Addresses to remove from the blacklist
     */
    function updateBlacklist(
        address[] calldata addressesToAdd,
        address[] calldata addressesToRemove
    )
        external
        onlyUpdater
    {
        _removeFromBlacklist(addressesToRemove);
        _addToBlacklist(addressesToAdd);
    }

    /**
     * @notice Get current blacklist
     * @return address[] Current blacklist
     */
    function blacklist() external view returns (address[] memory) {
        return blacklistSet.values();
    }

    /**
     * @notice Get current blacklist length
     * @return uint256 Current blacklist length
     */
    function blacklistLength() external view returns (uint256) {
        return blacklistSet.length();
    }

    /**
     * @notice Internal implementation of addToBlacklist
     * @param newBlacklistEntries New addresses to add to blacklist
     */
    function _addToBlacklist(address[] memory newBlacklistEntries) internal {
        for (uint256 i = 0; i < newBlacklistEntries.length; i++) {
            // solhint-disable-next-line gas-custom-errors
            require(!blacklistSet.contains(newBlacklistEntries[i]), "Address already in blacklist");
            isBlacklisted[newBlacklistEntries[i]] = true;
            blacklistSet.add(newBlacklistEntries[i]);
            emit Blacklisted(newBlacklistEntries[i]);
        }
    }

    /**
     * @notice Internal implementation of removeFromBlacklist
     * @param blacklistEntriesToRemove Addresses to remove from the blacklist
     */
    function _removeFromBlacklist(address[] calldata blacklistEntriesToRemove) internal {
        for (uint256 i = 0; i < blacklistEntriesToRemove.length; i++) {
            // solhint-disable-next-line gas-custom-errors
            require(blacklistSet.contains(blacklistEntriesToRemove[i]), "Address not in blacklist");
            delete isBlacklisted[blacklistEntriesToRemove[i]];
            blacklistSet.remove(blacklistEntriesToRemove[i]);
            emit UnBlacklisted(blacklistEntriesToRemove[i]);
        }
    }
}
