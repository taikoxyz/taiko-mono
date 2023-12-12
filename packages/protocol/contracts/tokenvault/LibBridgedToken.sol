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

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/// @title LibBridgedToken
library LibBridgedToken {
    function buildName(
        string memory name,
        uint256 srcChainId
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat("Bridged ", name, unicode" (⭀", Strings.toString(srcChainId), ")");
    }

    function buildSymbol(string memory symbol) internal pure returns (string memory) {
        return string.concat(symbol, ".t");
    }
}
