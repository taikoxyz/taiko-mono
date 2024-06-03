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

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Mock ERC20 for Taiko Airdrop
contract MockERC20 is ERC20, Ownable {
    /// @notice Mints 50 Million mock TKO tokens to the vault
    constructor() ERC20("MockTKO", "mTKO") { }

    /// @notice Mints a large amount of tokens directly to a specified address.
    /// @param to The address to mint the tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
