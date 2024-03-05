// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../BridgedERC20Base.sol";

/// @title IUSDC
/// @custom:security-contact security@taiko.xyz
interface IUSDC is IERC20 {
    /// @notice Burns a specific amount of tokens.
    /// @param _amount The amount of token to be burned.
    function burn(uint256 _amount) external;

    /// @notice Mints a specific amount of new tokens to an address.
    /// @param _to The address that will receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external;
}

/// @title USDCAdapter
/// @custom:security-contact security@taiko.xyz
contract USDCAdapter is BridgedERC20Base {
    using SafeERC20 for IUSDC;

    /// @notice The USDC instance.
    /// @dev Slot 1.
    IUSDC public usdc;
    uint256[49] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _usdc The USDC instance.
    function init(address _owner, address _addressManager, IUSDC _usdc) external initializer {
        __Essential_init(_owner, _addressManager);
        usdc = _usdc;
    }

    function _mintToken(address _account, uint256 _amount) internal override {
        usdc.mint(_account, _amount);
    }

    function _burnToken(address _from, uint256 _amount) internal override {
        usdc.safeTransferFrom(_from, address(this), _amount);
        usdc.burn(_amount);
    }
}
