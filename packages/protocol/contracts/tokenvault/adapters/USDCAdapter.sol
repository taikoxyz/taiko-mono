// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

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
        __Essential_init(_owner, _adressManager);
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
