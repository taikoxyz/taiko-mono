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

interface IUSDC {
    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title USDCAdapter
contract USDCAdapter is BridgedERC20Base {
    IUSDC public usdc; // slot 1
    uint256[49] private __gap;

    function init(address _owner, address _adressManager, IUSDC _usdc) external initializer initEssential(_owner, _adressManager
        ){
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
