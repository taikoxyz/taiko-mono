// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { MockUnzenInbox } from "./MockUnzenInbox.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxSwitchTestBase
/// @notice An Inbox on a network that switches from Unzen (SWITCH.md): initialized with a mock
/// Unzen Inbox and `FORK_TIME`, its start not yet written, L1 at block 11 with reference block 10
/// and two blobs per landing.
/// @dev The committed chain is the base's from the start S = 1000 on, with forced inclusion
/// cursor 0 throughout and Comet hash 0 at S. `_finalizeUnzen` closes the Unzen proposals at
/// `PROPOSE_CUTOFF` and finalizes them up to S, whose checkpoint the final proof saves through the
/// forwarder; `_writeStart` then has Carol, any caller, latch S at `FORK_TIME` (START-10-5a,
/// LAND-6.1-8a).
abstract contract EtnaInboxSwitchTestBase is EtnaLandTestBase {
    /// @dev The Etna start, the last Unzen block.
    uint256 internal constant S = 1000;

    /// @dev `ETNA_FORK_TIME`.
    uint48 internal constant FORK_TIME = 1_000_000;

    /// @dev The Unzen Inbox's propose cutoff, `ETNA_FORK_TIME - PROPOSE_MARGIN` with a 12 s margin.
    uint48 internal constant PROPOSE_CUTOFF = FORK_TIME - 12;

    MockUnzenInbox internal unzen;

    function setUp() public virtual override {
        EtnaInboxTestBase.setUp();
        unzen = new MockUnzenInbox();
        inboxImpl = _newInboxImpl(_switchConfig());
        _upgradeAndInit(inboxImpl, _switchInitParams());
        vm.roll(LEAN_REFERENCE_BLOCK + 1);
        _setReference(LEAN_REFERENCE_BLOCK, LEAN_REFERENCE_HASH);
        _setBlobCount(2);
    }

    /// @dev The base's chain with forced inclusion cursor and start Comet hash zero.
    function _cut(uint256 _x)
        internal
        pure
        virtual
        override
        returns (bytes32 el_, bytes32 comet_, uint256 head_)
    {
        return (bytes32(100 + _x), _x == S ? bytes32(0) : bytes32(200 + _x), 0);
    }

    /// @dev The default configuration with the mock Unzen Inbox and `FORK_TIME`.
    function _switchConfig() internal view returns (IEtnaInbox.Config memory config_) {
        config_ = _defaultConfig();
        (config_.unzenInbox, config_.etnaForkTime) = (address(unzen), FORK_TIME);
    }

    /// @dev The default inputs without a genesis hash or state root.
    function _switchInitParams() internal view returns (IEtnaInbox.InitParams memory params_) {
        params_ = _defaultInitParams();
        (params_.genesisBlockHash, params_.genesisStateRoot) = (0, 0);
    }

    function _startHash() internal pure returns (bytes32 hash_) {
        (hash_,,) = _cut(S);
    }

    function _startStateRoot() internal pure returns (bytes32) {
        return _stateRoot(S);
    }

    /// @dev Finalizes Unzen up to S (`_finalizeUnzen`), then Carol, an unrelated caller, latches
    /// the start S at `FORK_TIME`.
    function _writeStart() internal {
        _finalizeUnzen();
        vm.warp(FORK_TIME);
        vm.prank(Carol);
        _inbox().setOrigin(uint48(S));
    }

    /// @dev The Unzen Inbox's proposals closed at `PROPOSE_CUTOFF` and it has finalized proposals
    /// 1 to 7 up to S, whose checkpoint its final proof saved through the Inbox's `saveCheckpoint`
    /// forwarder. Only before the start write: the start write closes the forwarder.
    function _finalizeUnzen() internal {
        unzen.setProposeCutoff(PROPOSE_CUTOFF);
        unzen.setCoreState(8, 7, _startHash());
        _saveUnzenCheckpoint(_startHash(), _startStateRoot());
    }

    /// @dev Saves the SignalService checkpoint at S as the Unzen Inbox's final proof would.
    function _saveUnzenCheckpoint(bytes32 _blockHash, bytes32 _stateRoot) internal {
        _forwardUnzenCheckpoint(S, _blockHash, _stateRoot);
    }

    /// @dev Calls the Inbox's `saveCheckpoint` as the Unzen Inbox's `prove` does.
    function _forwardUnzenCheckpoint(
        uint256 _height,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        vm.prank(address(unzen));
        EtnaInbox(inboxProxy)
            .saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: uint48(_height), blockHash: _blockHash, stateRoot: _stateRoot
                })
            );
    }
}
