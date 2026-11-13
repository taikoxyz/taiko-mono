// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { MockUnzenInbox } from "./MockUnzenInbox.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxSwitchTestBase
/// @notice An Inbox on a network that switches from Unzen (SWITCH.md): initialized with Carol as
/// the originWriter, a mock Unzen Inbox and `FORK_TIME`, its start not yet written, L1 at block 11
/// with reference block 10 and two blobs per landing.
/// @dev The committed chain is the base's from the start S = 1000 on, with forced inclusion
/// cursor 0 throughout and Comet hash 0 at S. `_writeStart` has Carol write S at `FORK_TIME`;
/// `_finalizeUnzen` makes the Unzen side pass the first-landing check (spec 6.1 LAND-6.1-8a).
abstract contract EtnaInboxSwitchTestBase is EtnaLandTestBase {
    /// @dev The Etna start, the last Unzen block; not a multiple of K, so the grid counted from S
    /// differs from the one counted from block 0.
    uint256 internal constant S = 1000;

    /// @dev `ETNA_FORK_TIME`.
    uint48 internal constant FORK_TIME = 1_000_000;

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

    /// @dev The switching start also has a zero validator-state commitment.
    function _valStateHash(uint256 _x) internal pure override returns (bytes32) {
        return _x == S ? bytes32(0) : bytes32(400 + _x);
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

    /// @dev The default configuration with Carol, the mock Unzen Inbox and `FORK_TIME`.
    function _switchConfig() internal view returns (IEtnaInbox.Config memory config_) {
        config_ = _defaultConfig();
        (config_.originWriter, config_.unzenInbox, config_.etnaForkTime) =
        (Carol, address(unzen), FORK_TIME);
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

    /// @dev Carol writes the start S at `FORK_TIME`.
    function _writeStart() internal {
        vm.warp(FORK_TIME);
        vm.prank(Carol);
        _inbox().setOrigin(S, _startHash(), _startStateRoot());
    }

    /// @dev The Unzen Inbox has finalized proposals 1 to 7 up to S, whose checkpoint its final
    /// proof saved in the SignalService (modelled by saving it as the SignalService's syncer).
    function _finalizeUnzen() internal {
        unzen.setCoreState(8, 7, _startHash());
        _saveUnzenCheckpoint(_startHash(), _startStateRoot());
    }

    /// @dev Saves the SignalService checkpoint at S as the Unzen Inbox's final proof would.
    function _saveUnzenCheckpoint(bytes32 _blockHash, bytes32 _stateRoot) internal {
        vm.prank(inboxProxy);
        signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: uint48(S), blockHash: _blockHash, stateRoot: _stateRoot
            })
        );
    }
}
