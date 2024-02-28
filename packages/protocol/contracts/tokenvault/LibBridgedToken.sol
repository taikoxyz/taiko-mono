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

import "@openzeppelin/contracts/utils/Strings.sol";

/// @title LibBridgedToken
/// @custom:security-contact security@taiko.xyz
library LibBridgedToken {
    error BTOKEN_INVALID_PARAMS();

    function validateInputs(
        address _srcToken,
        uint256 _srcChainId,
        string memory _symbol,
        string memory _name
    )
        internal
        view
    {
        if (
            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
                || bytes(_symbol).length == 0 || bytes(_name).length == 0
        ) {
            revert BTOKEN_INVALID_PARAMS();
        }
    }

    function buildName(
        string memory _name,
        uint256 _srcChainId
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat("Bridged ", _name, unicode" (⭀", Strings.toString(_srcChainId), ")");
    }

    function buildSymbol(string memory _symbol) internal pure returns (string memory) {
        return string.concat(_symbol, ".t");
    }

    function buildURI(
        address _srcToken,
        uint256 _srcChainId
    )
        internal
        pure
        returns (string memory)
    {
        // Creates a base URI in the format specified by EIP-681:
        // https://eips.ethereum.org/EIPS/eip-681
        return string(
            abi.encodePacked(
                "ethereum:",
                Strings.toHexString(uint160(_srcToken), 20),
                "@",
                Strings.toString(_srcChainId),
                "/tokenURI?uint256="
            )
        );
    }
}
