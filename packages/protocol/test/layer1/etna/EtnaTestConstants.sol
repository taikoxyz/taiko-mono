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
    uint256 internal constant FORFEIT_BPS = 1000;
    address internal constant SLASH_SINK = address(0x5151);

    /// @dev `erc7201("taiko.etna.registry")`: the registry's base slot R.
    uint256 internal constant REGISTRY_BASE =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;

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
            inbox: _inbox,
            forfeitBps: FORFEIT_BPS
        });
    }

    /// @dev The entry key of bond `_bondId` in `_registry`: keccak256(abi.encode(ckPrefix, ckX)).
    function _entryKey(
        IEtnaStakingRegistry _registry,
        uint256 _bondId
    )
        internal
        view
        returns (bytes32)
    {
        IEtnaStakingRegistry.Entry memory entry = _registry.bondAt(_bondId).entry;
        return keccak256(abi.encode(entry.ckPrefix, entry.ckX));
    }

    /// @dev `keccak256(abi.encode(uint256(keccak256(_namespace)) - 1)) & ~0xff`.
    function _erc7201(string memory _namespace) internal pure returns (bytes32) {
        return
            keccak256(abi.encode(uint256(keccak256(bytes(_namespace))) - 1))
                & ~bytes32(uint256(0xff));
    }
}
