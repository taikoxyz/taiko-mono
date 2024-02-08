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

interface IHopRelayRegistry {
    function isRelayRegistered(
        uint64 srcChainId,
        uint64 relayerChainId,
        address relayer
    )
        external
        view
        returns (bool);
}

/// @title HopRelayRegistry
contract HopRelayRegistry is EssentialContract, IHopRelayRegistry {
    mapping(uint64 => mapping(uint64 => mapping(address => bool))) internal registry;
    uint256[49] private __gap;

    event RelayRegistered(
        uint64 indexed srcChainId,
        uint64 indexed hopChainId,
        address indexed hopRelay,
        bool registered
    );

    error MHG_INVALID_PARAMS();
    error MHG_INVALID_STATE();

    function init() external initializer {
        __Essential_init();
    }

    function registerRelay(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelay
    )
        external
        onlyOwner
    {
        _registerRelay(srcChainId, hopChainId, hopRelay, true);
    }

    function deregisterRelay(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelay
    )
        external
        onlyOwner
    {
        _registerRelay(srcChainId, hopChainId, hopRelay, false);
    }

    function isRelayRegistered(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelay
    )
        public
        view
        returns (bool)
    {
        return registry[srcChainId][hopChainId][hopRelay];
    }

    function _registerRelay(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelay,
        bool registered
    )
        private
    {
        if (
            srcChainId == 0 || hopChainId == 0 || srcChainId == hopChainId
                || hopRelay == address(0)
        ) {
            revert MHG_INVALID_PARAMS();
        }
        if (registry[srcChainId][hopChainId][hopRelay] == registered) {
            revert MHG_INVALID_STATE();
        }
        registry[srcChainId][hopChainId][hopRelay] = registered;
        emit RelayRegistered(srcChainId, hopChainId, hopRelay, registered);
    }
}
