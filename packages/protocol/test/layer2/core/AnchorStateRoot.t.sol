// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AnchorTestBase, MockCheckpointStore } from "./Anchor.t.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";

contract AnchorStateRootTest is AnchorTestBase {
    bytes32 private constant L1_STATE_ROOT =
        0x270a592f64f7aacbedfb9e5b5d850860e6beeb9830df58fb56c4678ec18740f9;

    Anchor private _anchor;
    MockCheckpointStore private _checkpointStore;

    function setUp() external {
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        _checkpointStore = new MockCheckpointStore();
        _anchor = _deployAnchor(_checkpointStore, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_ReturnsCheckpointRootBeforeEtna() external {
        uint48 blockNumber = 1000;
        _checkpointStore.saveCheckpoint(_checkpoint(blockNumber, 123, uint256(L1_STATE_ROOT)));
        // A retained oracle entry for the same number must not replace the checkpoint root.
        _recordBeaconRoot(blockNumber, bytes32(uint256(123)));
        vm.warp(ETNA_TIMESTAMP - 1);

        assertEq(_anchor.getL1StateRoot(blockNumber), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_ReturnsExecutionStateRootAtEtna() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_STATE_ROOT);

        assertEq(_getL1StateRoot(_anchor, ETNA_TIMESTAMP), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_ReturnsExecutionStateRootAfterEtna() external {
        _recordBeaconRoot(ETNA_TIMESTAMP + 12, L1_STATE_ROOT);

        assertEq(_getL1StateRoot(_anchor, ETNA_TIMESTAMP + 12), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_ReturnsHistoricalRootWhileSlotRetained() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_STATE_ROOT);
        _recordBeaconRoot(ETNA_TIMESTAMP + 12, bytes32(uint256(123)));

        assertEq(_getL1StateRoot(_anchor, ETNA_TIMESTAMP), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_DoesNotSaveCheckpointOrChangeAnchorState() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_STATE_ROOT);
        Anchor.BlockState memory beforeState = _anchor.getBlockState();
        vm.recordLogs();

        assertEq(_getL1StateRoot(_anchor, ETNA_TIMESTAMP), L1_STATE_ROOT);

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(_checkpointStore.getCheckpoint(23_000_000).stateRoot, bytes32(0));
        Anchor.BlockState memory afterState = _anchor.getBlockState();
        assertEq(afterState.anchorBlockNumber, beforeState.anchorBlockNumber);
        assertEq(afterState.ancestorsHash, beforeState.ancestorsHash);
    }

    function test_getL1StateRoot_RevertWhen_CheckpointRootZeroBeforeEtna() external {
        uint48 blockNumber = 1000;
        _checkpointStore.saveCheckpoint(_checkpoint(blockNumber, 123, 0));
        _recordBeaconRoot(blockNumber, L1_STATE_ROOT);
        vm.warp(ETNA_TIMESTAMP - 1);

        _expectGetterRevert(_anchor, blockNumber);
    }

    function test_getL1StateRoot_ReturnsCheckpointRootWhenEtnaNeverActivates() external {
        Anchor anchor = _deployAnchor(_checkpointStore, type(uint64).max);
        uint48 blockNumber = 1000;
        _checkpointStore.saveCheckpoint(_checkpoint(blockNumber, 123, uint256(L1_STATE_ROOT)));
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(uint256(123)));

        assertEq(_getL1StateRoot(anchor, blockNumber), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_RevertWhen_PreEtnaBlockNumberWouldTruncate() external {
        uint48 blockNumber = 1000;
        _checkpointStore.saveCheckpoint(_checkpoint(blockNumber, 123, uint256(L1_STATE_ROOT)));
        vm.warp(ETNA_TIMESTAMP - 1);

        uint64 oversizedBlockNumber = uint64(blockNumber) + (uint64(1) << 48);
        _expectGetterRevert(_anchor, oversizedBlockNumber, Anchor.InvalidL1BlockNumber.selector);
    }

    function test_getL1StateRoot_RevertWhen_PreEtnaTimestampQueriedAfterEtna() external {
        uint48 blockNumber = uint48(ETNA_TIMESTAMP - 1);
        _checkpointStore.saveCheckpoint(_checkpoint(blockNumber, 123, uint256(L1_STATE_ROOT)));
        _recordBeaconRoot(blockNumber, L1_STATE_ROOT);
        vm.warp(ETNA_TIMESTAMP);

        _expectGetterRevert(_anchor, blockNumber, Anchor.EtnaNotActive.selector);
    }

    function test_getL1StateRoot_ReturnsRootWhenEtnaActiveFromGenesis() external {
        Anchor anchor = _deployAnchor(_checkpointStore, 0);
        _recordBeaconRoot(1, L1_STATE_ROOT);

        assertEq(_getL1StateRoot(anchor, 1), L1_STATE_ROOT);
    }

    function test_getL1StateRoot_RevertWhen_ZeroRootRecorded() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(0));

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_RevertWhen_TimestampNotRecorded() external {
        vm.warp(ETNA_TIMESTAMP);

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_RevertWhen_RingBufferSlotOverwritten() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_STATE_ROOT);
        _recordBeaconRoot(ETNA_TIMESTAMP + 8191, bytes32(uint256(123)));

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_RevertWhen_BeaconRootsHasNoCode() external {
        vm.etch(BEACON_ROOTS, "");
        vm.warp(ETNA_TIMESTAMP);

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_RevertWhen_OracleReturnIsShort() external {
        // Return 31 bytes, even though they are nonzero.
        vm.etch(BEACON_ROOTS, hex"6001600052601f6000f3");
        vm.warp(ETNA_TIMESTAMP);

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function test_getL1StateRoot_RevertWhen_OracleReturnIsLong() external {
        vm.etch(BEACON_ROOTS, hex"600160005260216000f3");
        vm.warp(ETNA_TIMESTAMP);

        _expectGetterRevert(_anchor, ETNA_TIMESTAMP);
    }

    function _getL1StateRoot(Anchor _provider, uint64 _blockId) private view returns (bytes32) {
        (bool ok, bytes memory result) = address(_provider)
            .staticcall(abi.encodeWithSignature("getL1StateRoot(uint64)", _blockId));
        assertTrue(ok, "state root getter reverted");
        assertEq(result.length, 32, "state root getter returned malformed data");
        return abi.decode(result, (bytes32));
    }

    function _expectGetterRevert(Anchor _provider, uint64 _blockId) private view {
        _expectGetterRevert(_provider, _blockId, bytes4(keccak256("L1StateRootNotFound()")));
    }

    function _expectGetterRevert(Anchor _provider, uint64 _blockId, bytes4 _error) private view {
        (bool ok, bytes memory result) = address(_provider)
            .staticcall(abi.encodeWithSignature("getL1StateRoot(uint64)", _blockId));
        assertFalse(ok, "state root getter accepted invalid input");
        assertEq(bytes4(result), _error, "wrong getter error");
    }
}
