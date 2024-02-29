// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../BridgedERC20Base.sol";

/// @title IUSDC
/// @custom:security-contact security@taiko.xyz
interface IUSDC {
    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

/// @title USDCAdapter
/// @custom:security-contact security@taiko.xyz
contract USDCAdapter is BridgedERC20Base {
    IUSDC public usdc; // slot 1
    uint256[49] private __gap;

    function init(address _owner, address _adressManager, IUSDC _usdc) external initializer {
        _Essential_init(_owner, _adressManager);
        usdc = _usdc;
    }

    function _mintToken(address _account, uint256 _amount) internal override {
        usdc.mint(_account, _amount);
    }

    function _burnToken(address _from, uint256 _amount) internal override {
        usdc.transferFrom(_from, address(this), _amount);
        usdc.burn(_amount);
    }
}
