// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC20Upgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { BridgeErrors } from "./BridgeErrors.sol";

/**
 * This contract is an upgradeable ERC20 contract that represents tokens bridged
 * from another chain.
 * @custom:security-contact hello@taiko.xyz
 */
contract BridgedERC20 is
    EssentialContract,
    IERC20Upgradeable,
    IERC20MetadataUpgradeable,
    ERC20Upgradeable,
    BridgeErrors
{
    address public srcToken;
    uint256 public srcChainId;
    uint8 private srcDecimals;
    uint256[47] private __gap;

    event BridgeMint(address indexed account, uint256 amount);
    event BridgeBurn(address indexed account, uint256 amount);

    /**
     * Initializes the contract.
     * @dev Different BridgedERC20 Contract to be deployed
     * per unique _srcToken i.e. one for USDC, one for USDT etc.
     * @param _addressManager The address manager.
     * @param _srcToken The source token address.
     * @param _srcChainId The source chain ID.
     * @param _decimals The number of decimal places of the source token.
     * @param _symbol The symbol of the token.
     * @param _name The name of the token.
     */
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
        if (
            _srcToken == address(0) || _srcChainId == 0
                || _srcChainId == block.chainid || bytes(_symbol).length == 0
                || bytes(_name).length == 0
        ) {
            revert B_INIT_PARAM_ERROR();
        }
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init({ name_: _name, symbol_: _symbol });
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcDecimals = _decimals;
    }

    /**
     * Mints tokens to an account.
     * @dev Only a TokenVault can call this function.
     * @param account The account to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function bridgeMintTo(
        address account,
        uint256 amount
    )
        public
        onlyFromNamed("token_vault")
    {
        _mint(account, amount);
        emit BridgeMint(account, amount);
    }

    /**
     * Burns tokens from an account.
     * @dev Only a TokenVault can call this function.
     * @param account The account to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function bridgeBurnFrom(
        address account,
        uint256 amount
    )
        public
        onlyFromNamed("token_vault")
    {
        _burn(account, amount);
        emit BridgeBurn(account, amount);
    }

    /**
     * Transfers tokens from the caller to another account.
     * @dev Any address can call this. Caller must have at least 'amount' to
     * call this.
     * @param to The account to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert B_ERC20_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transfer(to, amount);
    }

    /**
     * Transfers tokens from one account to another account.
     * @dev Any address can call this. Caller must have allowance of at least
     * 'amount' for 'from's tokens.
     * @param from The account to transfer tokens from.
     * @param to The account to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
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
            revert B_ERC20_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    /**
     * Gets the number of decimal places of the token.
     * @return The number of decimal places of the token.
     */
    function decimals()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return srcDecimals;
    }

    /**
     * Gets the source token address and the source chain ID.
     * @return The source token address and the source chain ID.
     */
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}

contract ProxiedBridgedERC20 is Proxied, BridgedERC20 { }
