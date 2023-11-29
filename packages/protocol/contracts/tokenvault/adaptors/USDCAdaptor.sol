// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../common/EssentialContract.sol";
import "../IBridgedERC20.sol";

interface IUSDC {
    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
}

/// @title USDCAdaptor
contract USDCAdaptor is EssentialContract, IBridgedERC20 {
    IUSDC public usdc;
    address public migratingFrom;
    uint256[48] private __gap;

    error INVALID_PARAMS();
    error PERMISSION_DENIED();
    error UNSUPPORTED_OP();

    function init(address _adressManager, IUSDC _usdc) external initializer {
        _Essential_init(_adressManager);
        usdc = _usdc;
    }

    function mint(address account, uint256 amount) external nonReentrant whenNotPaused {
        if (msg.sender != resolve("erc20_vault", true) && msg.sender != migratingFrom) {
            revert PERMISSION_DENIED();
        }

        usdc.mint(account, amount);
    }

    /// @dev Warning:
    /// 1) Users must set up allowances for this adaptor so USDC can be transferred from users
    /// addresses to the adaptor.
    /// 2) This adaptor must be granted the correct role by the USDC contract in order to burn
    /// native USDC tokens.
    function burn(
        address from,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc20_vault")
    {
        usdc.transferFrom(from, address(this), amount);
        usdc.burn(amount);
    }

    function startInboundMigration(address from)
        external
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc20_vault")
    {
        if (migratingFrom != address(0)) revert PERMISSION_DENIED();
        if (from == address(0)) revert INVALID_PARAMS();

        migratingFrom = from;
    }

    function stopInboundMigration() external nonReentrant whenNotPaused onlyOwner {
        if (migratingFrom == address(0)) revert PERMISSION_DENIED();
        migratingFrom = address(0);
    }

    function startOutboundMigration(address) external pure {
        revert UNSUPPORTED_OP();
    }
}
