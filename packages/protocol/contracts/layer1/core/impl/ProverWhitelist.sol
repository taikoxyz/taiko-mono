// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IProverWhitelist.sol";
import "src/shared/common/EssentialContract.sol";

import "./ProverWhitelist_Layout.sol"; // DO NOT DELETE

/// @title ProverWhitelist
/// @notice Contract for managing whitelisted provers using a mapping
/// @custom:security-contact security@taiko.xyz
contract ProverWhitelist is EssentialContract, IProverWhitelist {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Mapping of prover addresses to their whitelist status
    mapping(address prover => bool isWhitelisted) private _provers;

    /// @notice The total number of whitelisted provers
    uint256 public proverCount;

    uint256[48] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a prover is enabled or disabled
    /// @param prover The address of the prover
    /// @param enabled True if the prover was enabled, false if disabled
    event ProverWhitelisted(address indexed prover, bool enabled);

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Enables or disables a prover
    /// @param _prover The address of the prover to update
    /// @param _enabled True to enable the prover, false to disable
    function whitelistProver(address _prover, bool _enabled) external onlyOwner {
        bool currentStatus = _provers[_prover];
        require(currentStatus != _enabled, ProverWhitelistedAlready());

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

    error ProverWhitelistedAlready();
}
