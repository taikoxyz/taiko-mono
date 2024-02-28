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

import "./EssentialContract.sol";

/// @title IAddressManager
/// @custom:security-contact security@taiko.xyz
/// @notice Specifies methods to manage address mappings for given chainId-name
/// pairs.
interface IAddressManager {
    /// @notice Gets the address mapped to a specific chainId-name pair.
    /// @dev Note that in production, this method shall be a pure function
    /// without any storage access.
    /// @param chainId The chainId for which the address needs to be fetched.
    /// @param name The name for which the address needs to be fetched.
    /// @return Address associated with the chainId-name pair.
    function getAddress(uint64 chainId, bytes32 name) external view returns (address);
}
