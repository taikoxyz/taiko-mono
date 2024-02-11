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

library LibSignals {
    function signalForStateRoot(
        uint64 chainId,
        bytes32 stateRoot
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode("STATE_ROOT", chainId, stateRoot));
    }

    function signalForStorageRoot(
        uint64 chainId,
        bytes32 storageRoot
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode("SIGNAL_SERVICE_STORAGE_ROOT", chainId, storageRoot));
    }
}
