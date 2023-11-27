// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../../common/EssentialContract.sol";

/// @notice We need to implement the 'relayer functions' - which will forward the calls the
/// ERC20Vault calls towards the L2 predeployed native contracts.
interface IERC20TokenVaultRelayer {
    /// @notice Mints `amount` tokens and assigns them to the `account` address.
    /// @param token The erc20 token contract.
    /// @param account The account to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address token, address account, uint256 amount) external;

    /// @notice Burns `amount` tokens from the `from` address.
    /// @param token The erc20 token contract.
    /// @param from The account from which the tokens will be burned.
    /// @param amount The amount of tokens to burn.
    function burn(address token, address from, uint256 amount) external;

    /// @notice Transfer `amount` tokens to `to` address.
    /// @param token The erc20 token contract.
    /// @param to The account who will receive the tokens.
    /// @param amount The amount of tokens.
    function transfer(address token, address to, uint256 amount) external returns (bool);

    /// @notice Transfer `amount` of tokens on behalf of `from` to `to` address (if approved).
    /// @param token The erc20 token contract.
    /// @param from The account who sends.
    /// @param to The account who will receive the tokens.
    /// @param amount The amount of tokens.
    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    )
        external
        returns (bool);
}

/// @title BaseTranslator
/// @notice It serves as a wrapper between the deployed USDC and the ERC20Vault - an extra layer for
/// flexibility. It is not an ERC20 contract, but we need to implement the interfaces the ERC20Vault
/// calls and relay over to other (native) contracts.
abstract contract BaseTranslator is EssentialContract, IERC20TokenVaultRelayer {
    struct CanonicalERC20 {
        uint64 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    mapping(address => CanonicalERC20) compatibilty1;
    mapping(uint256 => mapping(address => address)) compatibilty2;
    uint256[48] private __gap;

    /// @notice Initializes the contract.
    /// @param _addressManager The address manager
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }
}
