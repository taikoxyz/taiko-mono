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

pragma solidity 0.8.20;

import "../BridgedERC20Base.sol";

interface IUSDC {
    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
}

/// @title USDCAdaptor
contract USDCAdaptor is BridgedERC20Base {
    IUSDC public immutable USDC;

    uint256[49] private __gap;

    constructor(IUSDC _usdc) {
        USDC = _usdc;
    }

    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    function _mintToken(address account, uint256 amount) internal override {
        USDC.mint(account, amount);
    }

    function _burnToken(address from, uint256 amount) internal override {
        USDC.transferFrom(from, address(this), amount);
        USDC.burn(amount);
    }
}
