// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaStart
/// @notice Provides the Etna start used to bound legacy Unzen checkpoint writes.
/// @custom:security-contact security@taiko.xyz
interface IEtnaStart {
    /// @notice Returns the Etna start height and block hash.
    /// @dev Matches the EtnaInbox view of slots 272 and 273. Never reverts; a zero hash means the
    /// start has not been written, including while the Inbox uses its bootstrap implementation.
    /// @return height_ The last Unzen block height S, or zero before the start write.
    /// @return blockHash_ The hash of S; zero exactly before the start write.
    function etnaStart() external view returns (uint48 height_, bytes32 blockHash_);
}
