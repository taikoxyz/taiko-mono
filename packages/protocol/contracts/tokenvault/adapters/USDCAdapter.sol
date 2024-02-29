// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../BridgedERC20Base.sol";

/// @title IUSDC
/// @custom:security-contact security@taiko.xyz
interface IUSDC {
    /// @notice Burns a specific amount of tokens.
    /// @param amount The amount of token to be burned.
    function burn(uint256 amount) external;

    /// @notice Mints a specific amount of new tokens to an address.
    /// @param to The address that will receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external;

    /// @notice Transfers tokens from one address to another.
    /// @param from The address which you want to send tokens from.
    /// @param to The address which you want to transfer to.
    /// @param value The amount of tokens to be transferred.
    /// @return True if the transfer was successful, otherwise false.
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title USDCAdapter
/// @custom:security-contact security@taiko.xyz
contract USDCAdapter is BridgedERC20Base {
    /// @notice The USDC instance.
    /// @dev Slot 1.
    IUSDC public usdc;
    uint256[49] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    /// @param _adressManager The address of the {AddressManager} contract.
    /// @param _usdc The USDC instance.
    function init(address _owner, address _adressManager, IUSDC _usdc) external initializer {
        __Essential_init(_owner, _adressManager);
        usdc = _usdc;
    }

    function _mintToken(address account, uint256 amount) internal override {
        usdc.mint(account, amount);
    }

    function _burnToken(address from, uint256 amount) internal override {
        usdc.transferFrom(from, address(this), amount);
        usdc.burn(amount);
    }
}
