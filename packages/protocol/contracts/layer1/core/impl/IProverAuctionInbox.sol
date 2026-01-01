// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProverAuction } from "../iface/IProverAuction.sol";

/// @title IProverAuctionInbox
/// @notice Inbox-only interface for slashing.
/// @custom:security-contact security@taiko.xyz
interface IProverAuctionInbox is IProverAuction {
    /// @notice Slash a prover's bond for failing to prove within the time window.
    /// @param _prover Address of the prover to slash.
    /// @param _recipient Address to receive the reward (typically the actual prover).
    function slashProver(address _prover, address _recipient) external;
}
