// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "./IBridgedERC20.sol";

/// @title BridgedERC20Base
/// @custom:security-contact security@taiko.xyz
abstract contract BridgedERC20Base is EssentialContract, IBridgedERC20 {
    /// @notice The address of the contract to migrate tokens to or from.
    address public migratingAddress;

    /// @notice If true, signals migrating 'to', false if migrating 'from'.
    bool public migratingInbound;

    uint256[49] private __gap;

    /// @notice Emitted when the migration status is changed.
    /// @param addr The address migrating 'to' or 'from'.
    /// @param inbound If false then signals migrating 'from', true if migrating 'into'.
    event MigrationStatusChanged(address addr, bool inbound);

    /// @notice Emitted when tokens are migrated to or from the bridged token.
    /// @param fromToken The address of the bridged token.
    /// @param account The address of the account.
    /// @param amount The amount of tokens migrated.
    event MigratedTo(address indexed fromToken, address indexed account, uint256 amount);

    error BB_PERMISSION_DENIED();
    error BB_INVALID_PARAMS();
    error BB_MINT_DISALLOWED();

    /// @notice Start or stop migration to/from a specified contract.
    /// @param _migratingAddress The address migrating 'to' or 'from'.
    /// @param _migratingInbound If false then signals migrating 'from', true if migrating 'into'.
    function changeMigrationStatus(
        address _migratingAddress,
        bool _migratingInbound
    )
        external
        nonReentrant
        whenNotPaused
        onlyFromOwnerOrNamed("erc20_vault")
    {
        if (_migratingAddress == migratingAddress && _migratingInbound == migratingInbound) {
            revert BB_INVALID_PARAMS();
        }

        migratingAddress = _migratingAddress;
        migratingInbound = _migratingInbound;
        emit MigrationStatusChanged(_migratingAddress, _migratingInbound);
    }

    /// @notice Mints tokens to the specified account.
    /// @param _account The address of the account to receive the tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _account, uint256 _amount) public nonReentrant whenNotPaused {
        // mint is disabled while migrating outbound.
        if (_isMigratingOut()) revert BB_MINT_DISALLOWED();

        if (msg.sender == migratingAddress) {
            // Inbound migration
            emit MigratedTo(migratingAddress, _account, _amount);
        } else if (msg.sender != resolve("erc20_vault", true)) {
            // Bridging from vault
            revert BB_PERMISSION_DENIED();
        }

        _mintToken(_account, _amount);
    }

    /// @notice Burns tokens from the specified account.
    /// @param _account The address of the account to burn the tokens from.
    /// @param _amount The amount of tokens to burn.
    function burn(address _account, uint256 _amount) public nonReentrant whenNotPaused {
        if (_isMigratingOut()) {
            // Only the owner of the tokens himself can migrate out
            if (msg.sender != _account) revert BB_PERMISSION_DENIED();
            // Outbound migration
            emit MigratedTo(migratingAddress, _account, _amount);
            // Ask the new bridged token to mint token for the user.
            IBridgedERC20(migratingAddress).mint(_account, _amount);
        } else if (msg.sender != resolve("erc20_vault", true)) {
            // Only the vault can burn tokens when not migrating out
            revert RESOLVER_DENIED();
        }

        _burnToken(_account, _amount);
    }

    /// @notice Returns the owner.
    /// @return The address of the owner.
    function owner() public view override(IBridgedERC20, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    function _mintToken(address _account, uint256 _amount) internal virtual;

    function _burnToken(address _from, uint256 _amount) internal virtual;

    function _isMigratingOut() internal view returns (bool) {
        return migratingAddress != address(0) && !migratingInbound;
    }
}
