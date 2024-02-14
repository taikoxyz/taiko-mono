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

/// @title IHopRelayRegistry
/// @notice A registry of hop relays for multi-hop bridging.
//  A hop relay is a contract that relays a corresponding chain's state roots to its loal signal
// service.
interface IHopRelayRegistry {
    /// @dev Returns if a relay is trusted.
    /// @param srcChainId The source chain ID where state roots correspond to.
    /// @param hopChainId The hop relay's local chain ID.
    /// @param hopRelay The address of the relay.
    /// @return trusted True if the relay is a trusted one.
    function isRelayRegistered(
        uint64 srcChainId,
        uint64 hopChainId,
        address hopRelay
    )
        external
        view
        returns (bool trusted);
}
