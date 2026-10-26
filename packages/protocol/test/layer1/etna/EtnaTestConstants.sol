// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaTestConstants
/// @notice The deployment parameters shared by the Etna Inbox and registry test bases.
abstract contract EtnaTestConstants {
    uint64 internal constant L2_CHAIN_ID = 167_001;

    uint256 internal constant MIN_STAKE = 1000 ether;
    uint256 internal constant ACTIVATION_DELAY = 10;
    uint256 internal constant EXIT_DELAY = 20;
    uint256 internal constant WITHDRAWAL_DELAY = 30;
    uint256 internal constant SLASH_BOUNTY_BPS = 1000;
    address internal constant SLASH_SINK = address(0x5151);

    /// @dev The registry configuration with these parameters, staking `_token` and fixed to
    /// `_inbox`.
    function _registryConfig(
        address _token,
        address _inbox
    )
        internal
        pure
        returns (IEtnaStakingRegistry.Config memory)
    {
        return IEtnaStakingRegistry.Config({
            token: _token,
            minStake: MIN_STAKE,
            activationDelay: ACTIVATION_DELAY,
            exitDelay: EXIT_DELAY,
            withdrawalDelay: WITHDRAWAL_DELAY,
            slashBountyBps: SLASH_BOUNTY_BPS,
            slashSink: SLASH_SINK,
            l2ChainId: L2_CHAIN_ID,
            inbox: _inbox
        });
    }
}
