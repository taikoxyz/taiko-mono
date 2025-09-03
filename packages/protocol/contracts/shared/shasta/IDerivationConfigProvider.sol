// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IDerivationConfigProvider
/// @notice Interface for retrieving derivation configuration
/// @custom:security-contact security@taiko.xyz
interface IDerivationConfigProvider {
    /// @notice Configuration struct containing all derivation constants
    struct Config {
        uint256 proposalMaxBlobs;
        uint256 proposalMaxBytes;
        uint256 proposalMaxBlocks;
        uint256 blockMaxRawTransactions;
        uint256 anchorMaxOffset;
        uint256 timestampMaxOffset;
        uint256 maxBlockGasLimitChangePermyriad;
        uint256 minBlockGasLimit;
    }

    /// @notice Returns the derivation configuration
    /// @return config_ The derivation configuration containing all constants
    function getDerivationConfig() external view returns (Config memory config_);
}
