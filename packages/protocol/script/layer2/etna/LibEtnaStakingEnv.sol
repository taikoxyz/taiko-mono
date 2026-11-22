// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

/// @title LibEtnaStakingEnv
/// @notice Reads an `EtnaStaking` configuration from the environment, for the scripts that deploy
/// the contract or check a deployment against it, and checks the withdrawal-delay bound that both
/// apply.
/// @dev Required: TAIKO_TOKEN (the bridged TAIKO token on L2), L1_CHAIN_ID, INBOX_PROXY (the Etna
/// Inbox proxy on L1), ETNA_WITHDRAWAL_DELAY (L2 blocks), ETNA_SLASH_BOUNTY_BPS, ETNA_SLASH_SINK
/// and ETNA_FORFEIT_BPS. Optional, with the reference value when unset or empty: ETNA_MIN_STAKE
/// in token base units (7,812,500 TAIKO), ETNA_VP_UNIT (10^9), ETNA_N_MAX (128), ETNA_MISS_LIMIT
/// (3,600) and ETNA_MISS_SLASH_BPS (1,000). An optional variable that is set but malformed reverts
/// instead of falling back to its default. The library checks no bounds: `EtnaStaking`'s
/// constructor does.
/// @custom:security-contact security@taiko.xyz
library LibEtnaStakingEnv {
    /// @dev `minStake` when ETNA_MIN_STAKE is unset or empty: 10^27 / 128, so 128 seats cover
    /// TAIKO's fixed supply.
    uint256 internal constant DEFAULT_MIN_STAKE = 7_812_500 ether;

    /// @dev `vpUnit` when ETNA_VP_UNIT is unset or empty.
    uint256 internal constant DEFAULT_VP_UNIT = 1e9;

    /// @dev `nMax` when ETNA_N_MAX is unset or empty.
    uint256 internal constant DEFAULT_N_MAX = 128;

    /// @dev `missLimit` when ETNA_MISS_LIMIT is unset or empty.
    uint256 internal constant DEFAULT_MISS_LIMIT = 3600;

    /// @dev `missSlashBps` when ETNA_MISS_SLASH_BPS is unset or empty.
    uint256 internal constant DEFAULT_MISS_SLASH_BPS = 1000;

    /// @dev The largest U, the Etna Inbox's maximum number of unsettled L2 blocks, that the Inbox
    /// accepts.
    uint256 internal constant MAX_UNSETTLED_LIMIT = 262_144;

    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Reads the configuration.
    /// @return config_ The `EtnaStaking` constructor's configuration.
    function readConfig() internal view returns (IEtnaStaking.Config memory config_) {
        config_.token = _VM.envAddress("TAIKO_TOKEN");
        config_.l1ChainId = _VM.envUint("L1_CHAIN_ID");
        config_.inbox = _VM.envAddress("INBOX_PROXY");
        config_.minStake = _envUintOr("ETNA_MIN_STAKE", DEFAULT_MIN_STAKE);
        config_.vpUnit = _envUintOr("ETNA_VP_UNIT", DEFAULT_VP_UNIT);
        config_.nMax = _envUintOr("ETNA_N_MAX", DEFAULT_N_MAX);
        config_.missLimit = _envUintOr("ETNA_MISS_LIMIT", DEFAULT_MISS_LIMIT);
        config_.missSlashBps = _envUintOr("ETNA_MISS_SLASH_BPS", DEFAULT_MISS_SLASH_BPS);
        config_.withdrawalDelay = _VM.envUint("ETNA_WITHDRAWAL_DELAY");
        config_.slashBountyBps = _VM.envUint("ETNA_SLASH_BOUNTY_BPS");
        config_.slashSink = _VM.envAddress("ETNA_SLASH_SINK");
        config_.forfeitBps = _VM.envUint("ETNA_FORFEIT_BPS");
    }

    /// @dev Checks that `_withdrawalDelay` is at least U + 2 + the evidence window. U is an Etna
    /// Inbox value that no L2 contract holds, so neither `EtnaStaking` nor its constructor can
    /// check this bound.
    /// @param _withdrawalDelay The `EtnaStaking` withdrawal delay, in L2 blocks.
    /// @param _unsettledLimit U, which must be in [1, `MAX_UNSETTLED_LIMIT`].
    /// @param _evidenceWindowBlocks The double-sign evidence window, in L2 blocks; nonzero.
    function checkWithdrawalDelay(
        uint256 _withdrawalDelay,
        uint256 _unsettledLimit,
        uint256 _evidenceWindowBlocks
    )
        internal
        pure
    {
        require(
            _unsettledLimit != 0 && _unsettledLimit <= MAX_UNSETTLED_LIMIT, InvalidUnsettledLimit()
        );
        require(_evidenceWindowBlocks != 0, ZeroEvidenceWindow());
        // U + 2 cannot overflow, being at most 262,146.
        require(
            _withdrawalDelay >= _unsettledLimit + 2
                && _withdrawalDelay - _unsettledLimit - 2 >= _evidenceWindowBlocks,
            WithdrawalDelayTooShort()
        );
    }

    /// @dev Reads an optional integer, `_default` when unset or empty. A malformed value reverts;
    /// `vm.envOr` would return the default for it.
    /// @param _name The variable name.
    /// @param _default The value when the variable is unset or empty.
    /// @return The value.
    function _envUintOr(string memory _name, uint256 _default) private view returns (uint256) {
        bool set = _VM.envExists(_name) && bytes(_VM.envString(_name)).length != 0;
        return set ? _VM.envUint(_name) : _default;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidUnsettledLimit();
    error WithdrawalDelayTooShort();
    error ZeroEvidenceWindow();
}
