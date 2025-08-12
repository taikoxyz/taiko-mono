// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";

/// @title IPreconfRouter
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter is IProposeBatch {
    error ForcedInclusionNotSupported();
    error NotPreconferOrFallback();
    error ProposerIsNotPreconfer();

    /// @notice Configuration struct for preconf-related settings
    struct Config {
        /// @notice The number of slots for hand over
        uint256 handOverSlots;
        /// @notice Reserved space for future config values to maintain ABI compatibility
        uint256[9] __gap;
    }

    /// @notice Returns the preconf configuration
    /// @return The configuration struct
    function getConfig() external view returns (Config memory);
}
