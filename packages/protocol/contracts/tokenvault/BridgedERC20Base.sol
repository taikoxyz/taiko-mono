// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../common/EssentialContract.sol";
import "./IBridgedERC20.sol";

abstract contract BridgedERC20Base is EssentialContract, IBridgedERC20 {
    address public migratingAddress; // slot 1
    bool public migratingInbound;
    uint256[49] private __gap;

    event MigrationStatusChanged(address addr, bool inbound);

    event MigratedTo(address indexed token, address indexed account, uint256 amount);
    event MigratedFrom(address indexed token, address indexed account, uint256 amount);

    function changeMigrationStatus(address addr, bool inbound) external whenNotPaused {
        if (msg.sender != resolve("erc20_vault", true) && msg.sender != owner()) {
            revert("PERMISSION_DENIED();");
        }

        if (addr == migratingAddress && inbound == migratingInbound) {
            revert("BRIDGED_TOKEN_INVALID_PARAMS()");
        }

        migratingAddress = addr;
        migratingInbound = inbound;
        emit MigrationStatusChanged(addr, inbound);
    }

    /// @notice Mints tokens to an account.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) public nonReentrant whenNotPaused {
        // if (migratingTo != address(0)) revert BRIDGED_TOKEN_PERMISSION_DENIED();

        // if (msg.sender != resolve("erc20_vault", true)) {
        //     if (msg.sender != migratingFrom) revert BRIDGED_TOKEN_PERMISSION_DENIED();
        //     emit MigratedTo(migratingFrom, account, amount);
        // }

        _mintToken(account, amount);
    }

    /// @notice Burns tokens from an account.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint256 amount) public nonReentrant whenNotPaused {
        // if (migratingTo != address(0)) {
        //     emit MigratedTo(migratingTo, account, amount);
        //     // Ask the new bridged token to mint token for the user.
        //     IBridgedERC20(migratingTo).mint(account, amount);
        // } else {
        //     if (msg.sender != resolve("erc20_vault", true)) revert RESOLVER_DENIED();
        // }

        _burnToken(account, amount);
    }

    function _mintToken(address account, uint256 amount) internal virtual;
    function _burnToken(address from, uint256 amount) internal virtual;
}
