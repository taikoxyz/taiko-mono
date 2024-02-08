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

import "../common/EssentialContract.sol";

interface IMultihopGraph {
    function isTrustedRelayer(
        uint64 srcChainId,
        uint64 relayerChainId,
        address relayer
    )
        external
        view
        returns (bool);
}

/// @title MultihopGraph
contract MultihopGraph is EssentialContract, IMultihopGraph {
    mapping(uint64 => mapping(uint64 => mapping(address => bool))) internal trustedRelayers;
    uint256[49] private __gap;

    event RelayerTrusted(
        uint64 indexed srcChainId,
        uint64 indexed hopChainId,
        address indexed hopRelayer,
        bool trusted
    );

    error MG_INVALID_STATE();

    function init() external initializer {
        __Essential_init();
    }

    function addTrustedRelayer(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelayer
    )
        external
        onlyOwner
    {
        _setRelayer(srcChainId, hopChainId, hopRelayer, true);
    }

    function removeTrustedRelayer(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelayer
    )
        external
        onlyOwner
    {
        _setRelayer(srcChainId, hopChainId, hopRelayer, false);
    }

    function isTrustedRelayer(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelayer
    )
        public
        view
        returns (bool)
    {
        return trustedRelayers[srcChainId][hopChainId][hopRelayer];
    }

    function _setRelayer(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelayer,
        bool trusted
    )
        private
    {
        if (trustedRelayers[srcChainId][hopChainId][hopRelayer] == trusted) {
            revert MG_INVALID_STATE();
        }
        trustedRelayers[srcChainId][hopChainId][hopRelayer] = trusted;
        emit RelayerTrusted(srcChainId, hopChainId, hopRelayer, trusted);
    }
}
