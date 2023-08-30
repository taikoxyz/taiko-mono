// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IMintableERC20 } from "../common/IMintableERC20.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title BridgedERC20
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain.
contract BridgedERC20 is
    EssentialContract,
    IMintableERC20,
    IERC20MetadataUpgradeable,
    ERC20Upgradeable
{
    address public srcToken;
    uint256 public srcChainId;
    uint8 private srcDecimals;

    uint256[47] private __gap;

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();

    /// @notice Initializes the contract.
    /// @dev Different BridgedERC20 Contract is deployed per unique _srcToken
    /// (e.g., one for USDC, one for USDT, etc.).
    /// @param _addressManager The address manager.
    /// @param _srcToken The source token address.
    /// @param _srcChainId The source chain ID.
    /// @param _decimals The number of decimal places of the source token.
    /// @param _symbol The symbol of the token.
    /// @param _name The name of the token.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string memory _symbol,
        string memory _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid
        if (
            _srcToken == address(0) || _srcChainId == 0
                || _srcChainId == block.chainid || bytes(_symbol).length == 0
                || bytes(_name).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }

        // Initialize EssentialContract and ERC20Upgradeable
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init({ name_: _name, symbol_: _symbol });

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcDecimals = _decimals;
    }

    /// @notice Mints tokens to an account.
    /// @dev Only an ERC20Vault can call this function.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(
        address account,
        uint256 amount
    )
        public
        onlyFromNamed2("erc20_vault", "taiko")
    {
        _mint(account, amount);
        emit Transfer(address(0), account, amount);
    }

    /// @notice Burns tokens from an account.
    /// @dev Only an ERC20Vault can call this function.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(
        address account,
        uint256 amount
    )
        public
        onlyFromNamed("erc20_vault")
    {
        _burn(account, amount);
        emit Transfer(account, address(0), amount);
    }

    /// @notice Transfers tokens from the caller to another account.
    /// @dev Any address can call this. Caller must have at least 'amount' to
    /// call this.
    /// @param to The account to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transfer(to, amount);
    }

    /// @notice Transfers tokens from one account to another account.
    /// @dev Any address can call this. Caller must have allowance of at least
    /// 'amount' for 'from's tokens.
    /// @param from The account to transfer tokens from.
    /// @param to The account to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    /// @notice Gets the name of the token.
    /// @return The name of the token with the source chain ID appended.
    function name()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        return string.concat(
            super.name(), unicode" ⭀", Strings.toString(srcChainId)
        );
    }

    /// @notice Gets the number of decimal places of the token.
    /// @return The number of decimal places of the token.
    function decimals()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return srcDecimals;
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address and chain ID.
    function canonical() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}

/// @title ProxiedBridgedERC20
/// @notice Proxied version of the parent contract.
contract ProxiedBridgedERC20 is Proxied, BridgedERC20 { }
