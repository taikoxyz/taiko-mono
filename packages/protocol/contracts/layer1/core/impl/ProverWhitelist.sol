// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import "../iface/IProverWhitelist.sol";

/// @title ProverWhitelist
/// @notice Non-upgradeable contract for managing whitelisted provers.
/// @custom:security-contact security@taiko.xyz
contract ProverWhitelist is Ownable, IProverWhitelist {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Mapping of prover addresses to their whitelist status
    mapping(address prover => bool isWhitelisted) private _provers;

    /// @notice The total number of whitelisted provers
    uint256 public proverCount;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a prover is enabled or disabled
    /// @param prover The address of the prover
    /// @param enabled True if the prover was enabled, false if disabled
    event ProverWhitelisted(address indexed prover, bool enabled);

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the contract with the given owner
    /// @param _owner The owner of this contract
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Enables or disables a prover
    /// @param _prover The address of the prover to update
    /// @param _enabled True to enable the prover, false to disable
    function whitelistProver(address _prover, bool _enabled) external onlyOwner {
        bool currentStatus = _provers[_prover];
        if (_enabled) {
            require(!currentStatus, ProverWhitelistedAlready());
        } else {
            require(currentStatus, ProverNotWhitelisted());
        }

        _provers[_prover] = _enabled;
        if (_enabled) {
            ++proverCount;
        } else {
            --proverCount;
        }
        emit ProverWhitelisted(_prover, _enabled);
    }

    /// @inheritdoc IProverWhitelist
    function isProverWhitelisted(address _prover)
        external
        view
        returns (bool isWhitelisted_, uint256 proverCount_)
    {
        proverCount_ = proverCount;
        if (proverCount_ > 0) {
            isWhitelisted_ = _provers[_prover];
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @dev Reverts when attempting to whitelist an already whitelisted prover.
    error ProverWhitelistedAlready();
    /// @dev Reverts when attempting to disable a prover that is not whitelisted.
    error ProverNotWhitelisted();
}
