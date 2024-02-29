// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../BridgedERC20Base.sol";

/// @title IUSDC
/// @custom:security-contact security@taiko.xyz
interface IUSDC {
    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title USDCAdapter
/// @custom:security-contact security@taiko.xyz
contract USDCAdapter is BridgedERC20Base {
    IUSDC public usdc; // slot 1
    uint256[49] private __gap;

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
