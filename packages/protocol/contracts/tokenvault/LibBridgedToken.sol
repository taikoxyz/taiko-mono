// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";

/// @title LibBridgedToken
/// @custom:security-contact security@taiko.xyz
library LibBridgedToken {
    error BTOKEN_INVALID_PARAMS();

    function validateInputs(address _srcToken, uint256 _srcChainId) internal view {
        if (_srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid) {
            revert BTOKEN_INVALID_PARAMS();
        }
    }

    function validateInputs(
        address _srcToken,
        uint256 _srcChainId,
        string memory _symbol,
        string memory _name
    )
        internal
        view
    {
        validateInputs(_srcToken, _srcChainId);
        if (bytes(_symbol).length == 0 || bytes(_name).length == 0) {
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
        if (bytes(_name).length == 0) {
            return "";
        } else {
            return
                string.concat("Bridged ", _name, unicode" (⭀", Strings.toString(_srcChainId), ")");
        }
    }

    function buildSymbol(string memory _symbol) internal pure returns (string memory) {
        if (bytes(_symbol).length == 0) return "";
        else return string.concat(_symbol, ".t");
    }

    function buildURI(
        address _srcToken,
        uint256 _srcChainId,
        string memory _extraParams
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
                "/tokenURI?uint256=",
                _extraParams
            )
        );
    }
}
