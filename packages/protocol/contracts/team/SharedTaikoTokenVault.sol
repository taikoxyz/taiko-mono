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

import "../L1/TaikoToken.sol";

/// @title SharedTaikoTokenVault
/// A vault that takes custody of all Taiko token to be distributed by airdrop contracts and/or
/// timelock token pools.
contract SharedTaikoTokenVault is EssentialContract {
    TaikoToken public taikoToken;
    uint128[49] private __gap;

    error INVALID_PARAM();

    modifier addressNotZero(address addr) {
        if (addr == address(0)) revert INVALID_PARAM();
        _;
    }

    function init(address _taikoToken) external initializer addressNotZero(_taikoToken) {
        __Essential_init();
        taikoToken = TaikoToken(_taikoToken);
    }

    function delegateToOwner(address delegatee) external onlyOwner {
        address _delegatee = delegatee == address(0) ? owner() : delegatee;
        taikoToken.delegate(_delegatee);
    }

    function approve(address spender, uint256 amount) external onlyOwner {
        taikoToken.approve(spender, amount);
    }
}
