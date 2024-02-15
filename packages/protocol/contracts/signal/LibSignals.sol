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

import "./ISignalService.sol";
/// @title LibSignals

library LibSignals {
    bytes32 public constant STATE_ROOT = keccak256("STATE_ROOT");
    bytes32 public constant SIGNAL_ROOT = keccak256("SIGNAL_ROOT");

    event StateRootRelayed(
        uint64 indexed chainid,
        uint64 indexed blockId,
        address signalService,
        bytes32 stateRoot,
        bytes32 signal
    );

    function relayStateRoot(
        address signalService,
        uint64 chainId,
        uint64 blockId,
        bytes32 stateRoot
    )
        internal
    {
        bytes32 signal =
            ISignalService(signalService).relayChainData(chainId, STATE_ROOT, stateRoot);

        emit StateRootRelayed(chainId, blockId, signalService, stateRoot, signal);
    }
}
