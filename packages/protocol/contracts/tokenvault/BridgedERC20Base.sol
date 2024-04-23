// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
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
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_ERC20_VAULT)
        nonReentrant
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
    function mint(address _account, uint256 _amount) external whenNotPaused nonReentrant {
        // mint is disabled while migrating outbound.
        if (_isMigratingOut()) revert BB_MINT_DISALLOWED();

        address _migratingAddress = migratingAddress;
        if (msg.sender == _migratingAddress) {
            // Inbound migration
            emit MigratedTo(_migratingAddress, _account, _amount);
        } else if (msg.sender != resolve(LibStrings.B_ERC20_VAULT, true)) {
            // Bridging from vault
            revert BB_PERMISSION_DENIED();
        }

        _mint(_account, _amount);
    }

    /// @notice Burns tokens in case of 'migrating out' from msg.sender (EOA) or from the ERC20Vault
    /// if bridging back to canonical token.
    /// @param _amount The amount of tokens to burn.
    function burn(uint256 _amount) external whenNotPaused nonReentrant {
        if (_isMigratingOut()) {
            // Outbound migration
            emit MigratedTo(migratingAddress, msg.sender, _amount);
            // Ask the new bridged token to mint token for the user.
            IBridgedERC20(migratingAddress).mint(msg.sender, _amount);
        } else if (msg.sender != resolve(LibStrings.B_ERC20_VAULT, true)) {
            // When user wants to burn tokens only during 'migrating out' phase is possible. If
            // ERC20Vault burns the tokens, that will go through the burn(amount) function.
            revert RESOLVER_DENIED();
        }

        _burn(msg.sender, _amount);
    }

    /// @notice Returns the owner.
    /// @return The address of the owner.
    function owner() public view override(IBridgedERC20, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    function _mint(address _account, uint256 _amount) internal virtual;

    function _burn(address _from, uint256 _amount) internal virtual;

    function _isMigratingOut() private view returns (bool) {
        return migratingAddress != address(0) && !migratingInbound;
    }
}
