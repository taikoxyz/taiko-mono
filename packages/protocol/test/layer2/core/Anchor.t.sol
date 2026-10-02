// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RLPWriter } from "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract MockCheckpointStore is ICheckpointStore {
    mapping(uint48 blockNumber => Checkpoint checkpoint) private _checkpoints;

    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        _checkpoints[_checkpoint.blockNumber] = _checkpoint;
    }

    function getCheckpoint(uint48 _blockNumber) external view override returns (Checkpoint memory) {
        return _checkpoints[_blockNumber];
    }
}

abstract contract AnchorTestBase is Test {
    uint64 internal constant L1_CHAIN_ID = 1;
    uint64 internal constant ETNA_TIMESTAMP = 1_800_000_000;
    address internal constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    address internal constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address internal constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    /// @dev Runtime code of the canonical EIP-4788 contract, as deployed on Ethereum mainnet.
    bytes internal constant BEACON_ROOTS_CODE =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500";

    function _deployAnchor(
        ICheckpointStore _checkpointStore,
        uint64 _etnaTimestamp
    )
        internal
        returns (Anchor)
    {
        Anchor anchorImpl = new Anchor(_checkpointStore, L1_CHAIN_ID, _etnaTimestamp);
        return Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
    }

    function _checkpoint(
        uint48 _blockNumber,
        uint256 _blockHash,
        uint256 _stateRoot
    )
        internal
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber,
            blockHash: bytes32(_blockHash),
            stateRoot: bytes32(_stateRoot)
        });
    }

    /// @dev Records `_root` for `_timestamp` the way the EIP-4788 system call does.
    function _recordBeaconRoot(uint64 _timestamp, bytes32 _root) internal {
        vm.warp(_timestamp);
        vm.prank(SYSTEM_ADDRESS);
        (bool ok,) = BEACON_ROOTS.call(abi.encode(_root));
        assertTrue(ok, "beacon root not recorded");
    }

    /// @dev Builds an RLP list of `_fieldCount` items. Item 3 is `_stateRoot` and item 8 is
    /// `_number` when the list is long enough; every other item is a distinct 32-byte filler.
    function _syntheticHeader(
        uint256 _fieldCount,
        bytes memory _stateRoot,
        bytes memory _number
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes[] memory fields = new bytes[](_fieldCount);
        for (uint256 i; i < _fieldCount; ++i) {
            fields[i] = RLPWriter.writeBytes(abi.encodePacked(bytes32(i + 1)));
        }
        if (_fieldCount > 3) fields[3] = RLPWriter.writeBytes(_stateRoot);
        if (_fieldCount > 8) fields[8] = RLPWriter.writeBytes(_number);
        return RLPWriter.writeList(fields);
    }
}

contract AnchorTest is AnchorTestBase {
    uint64 private constant SHASTA_FORK_HEIGHT = 100;

    Anchor internal anchor;
    MockCheckpointStore internal checkpointStore;

    function setUp() external {
        checkpointStore = new MockCheckpointStore();
        anchor = _deployAnchor(checkpointStore, type(uint64).max);
    }

    function test_anchorV4_savesCheckpointAndUpdatesState() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, checkpoint.blockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        ICheckpointStore.Checkpoint memory saved =
            checkpointStore.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockNumber, checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash);
        assertEq(saved.stateRoot, checkpoint.stateRoot);

        assertEq(anchor.blockHashes(block.number - 1), blockhash(block.number - 1));
    }

    function test_anchorV4_allowsMultipleAnchorsAcrossBlocks() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, checkpoint.blockNumber);
    }

    function test_anchorV4_rejectsInvalidSender() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(checkpoint);
    }

    function test_anchorV4_ignoresStaleCheckpoint() external {
        ICheckpointStore.Checkpoint memory freshCheckpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(freshCheckpoint);

        ICheckpointStore.Checkpoint memory staleCheckpoint = _checkpoint(999, 0xAAAA, 0xBBBB);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(staleCheckpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, freshCheckpoint.blockNumber);
        assertEq(checkpointStore.getCheckpoint(staleCheckpoint.blockNumber).blockNumber, 0);
    }

    function test_anchorV4_succeedsBeforeEtna() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        etnaAnchor.anchorV4(checkpoint);

        assertEq(etnaAnchor.getBlockState().anchorBlockNumber, checkpoint.blockNumber);
        assertEq(etnaAnchor.etnaTimestamp(), ETNA_TIMESTAMP);
    }

    function test_anchorV4_RevertWhen_AtOrAfterEtna() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);
        vm.roll(SHASTA_FORK_HEIGHT);

        vm.warp(ETNA_TIMESTAMP);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(checkpoint);

        vm.warp(ETNA_TIMESTAMP + 1);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(checkpoint);
    }

    function test_anchorV4_RevertWhen_EtnaActiveFromGenesis() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, 0);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(0);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(_checkpoint(1000, 0x1234, 0x5678));
    }

    function test_anchorV4_succeedsWhenEtnaNeverActivates() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(type(uint64).max - 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        assertEq(anchor.getBlockState().anchorBlockNumber, checkpoint.blockNumber);
    }

    /// @dev Rehearses the fork-time forgery: in the first anchorless block, the public golden-touch
    /// key must not be able to anchor a forged checkpoint.
    function test_anchorV4_RevertWhen_ForgedInFirstEtnaBlock() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory lastCheckpoint = _checkpoint(1000, 0x1234, 0x5678);

        // The last pre-Etna block anchors normally.
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        etnaAnchor.anchorV4(lastCheckpoint);
        Anchor.BlockState memory stateBefore = etnaAnchor.getBlockState();

        // The first Etna block has no anchor transaction; a funded golden-touch call is rejected.
        ICheckpointStore.Checkpoint memory forged = _checkpoint(2000, 0xBAD, 0xBAD);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.warp(ETNA_TIMESTAMP);
        vm.deal(GOLDEN_TOUCH, 1 ether);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(forged);

        assertEq(checkpointStore.getCheckpoint(forged.blockNumber).blockHash, bytes32(0));
        Anchor.BlockState memory stateAfter = etnaAnchor.getBlockState();
        assertEq(stateAfter.anchorBlockNumber, stateBefore.anchorBlockNumber);
        assertEq(stateAfter.ancestorsHash, stateBefore.ancestorsHash);
    }

    function test_revealCheckpoint_savesWhenStoreReturnsEmptyCheckpoint() external {
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        bytes memory header =
            _syntheticHeader(21, abi.encodePacked(bytes32(uint256(0x5678))), hex"03e8");
        _recordBeaconRoot(ETNA_TIMESTAMP, keccak256(header));

        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);

        ICheckpointStore.Checkpoint memory saved = checkpointStore.getCheckpoint(1000);
        assertEq(saved.blockNumber, 1000);
        assertEq(saved.blockHash, keccak256(header));
        assertEq(saved.stateRoot, bytes32(uint256(0x5678)));
    }
}

contract AnchorRevealTest is AnchorTestBase {
    address private constant REMOTE_SIGNAL_SERVICE = address(0x5155);

    /// @dev Ethereum mainnet block 23,000,000 header, from `cast block 23000000 --raw`.
    bytes private constant L1_HEADER = hex"f90287a0f3d7043eaa58d8de0c2efba3dac09192e30e08152714c428bd8bcb48db1f9d6fa01dcc4de8dec75d7aab85b567b6"
        hex"ccd41ad312451b948a7413f0a142fd40d4934794396343362be2a4da1ce0c1c210945346fb82aa49a0270a592f64f7aacbed"
        hex"fb9e5b5d850860e6beeb9830df58fb56c4678ec18740f9a0b63d04180eff4bbc6aba90da636b28cf3360d9eeabb0a0787919"
        hex"94538c9d0e32a0805e3a7a8be48874562fbaa030ab0328399cd577dcbdc02ef9919ee20e0b33c7b90100907aba8087000811"
        hex"18a8c04190715e90c2c04863ae00480612611c102f3095b0920035b7a58930a62ad1fb2861e217a9f700a73ece8a7aa567e5"
        hex"fe5145a210130554940a45110e48ee0b6b2aa8e520ab03aa5c33b1450822960e5c89d56fc707910571292e650f26914dd82f"
        hex"88a4fc80a0c3d6f056ba0e2c92a4c5962a0a1f2e01ca8e8da8814d3c2871b3cc8b3130e7d3282c41ef80c09ba32f4dc675b2"
        hex"92ae12cc72746990aac03e763bcf3eb13c5a2018700b60b86426c5e77c33280c65752892eea2000e7b75291836352a2a7c44"
        hex"a275f6ca6d10d0911a590c4ed0502d96b0f0ad7101d039424074d629c00dc291071bc140293155d2099d8107568d11a78084"
        hex"015ef3c08402aea54083ab10598468842dc39be29ca82051756173617220287175617361722e77696e2920e29ca8a084753b"
        hex"f98ac6d83229d564980053d3df153a6182c74e2949c4e1494ff2030b87880000000000000000840e49b92da068d449aa1fe2"
        hex"fc872f7521f9a399dad207c8ad06fb9bf8666b5dcbb2e01096528312000083040000a03a3c6eaabf0eaf9f674853ee1bd2e2"
        hex"1f9ba6ecfff71baa293943bcb357bff686a0e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
    bytes32 private constant L1_BLOCK_HASH =
        0xe368c631c74a82c3043e6d44c4bef6e6139a6501b39c7700c2552554d10e6c3b;
    bytes32 private constant L1_STATE_ROOT =
        0x270a592f64f7aacbedfb9e5b5d850860e6beeb9830df58fb56c4678ec18740f9;
    uint48 private constant L1_BLOCK_NUMBER = 23_000_000;

    Anchor internal anchor;
    SignalService internal signalService;

    function setUp() external {
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);

        // The Anchor and SignalService proxies reference each other through immutables, so the
        // SignalService proxy address is computed first. Deployment order: anchor impl, anchor
        // proxy, signal service impl, signal service proxy.
        address signalServiceProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        anchor = _deployAnchor(ICheckpointStore(signalServiceProxy), ETNA_TIMESTAMP);

        SignalService signalServiceImpl =
            new SignalService(address(anchor), REMOTE_SIGNAL_SERVICE, address(0));
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        assertEq(address(signalService), signalServiceProxy);
    }

    function test_revealCheckpoint_savesRealL1Header() external {
        assertEq(keccak256(L1_HEADER), L1_BLOCK_HASH);
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_BLOCK_HASH);

        vm.expectEmit(address(signalService));
        emit ICheckpointStore.CheckpointSaved(L1_BLOCK_NUMBER, L1_BLOCK_HASH, L1_STATE_ROOT);
        ICheckpointStore.Checkpoint memory revealed =
            anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);

        assertEq(revealed.blockNumber, L1_BLOCK_NUMBER);
        assertEq(revealed.blockHash, L1_BLOCK_HASH);
        assertEq(revealed.stateRoot, L1_STATE_ROOT);

        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(L1_BLOCK_NUMBER);
        assertEq(saved.blockHash, L1_BLOCK_HASH);
        assertEq(saved.stateRoot, L1_STATE_ROOT);
    }

    function test_revealCheckpoint_isNoOpWhenAlreadyRevealed() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_BLOCK_HASH);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);

        vm.recordLogs();
        ICheckpointStore.Checkpoint memory revealed =
            anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(revealed.blockNumber, L1_BLOCK_NUMBER);
        assertEq(revealed.stateRoot, L1_STATE_ROOT);
    }

    /// @dev The first Etna block inherits its parent's anchor, whose checkpoint the last
    /// `anchorV4` already saved.
    function test_revealCheckpoint_isNoOpForCheckpointSavedByLastAnchor() external {
        vm.roll(100);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            ICheckpointStore.Checkpoint({
                blockNumber: L1_BLOCK_NUMBER, blockHash: L1_BLOCK_HASH, stateRoot: L1_STATE_ROOT
            })
        );

        vm.roll(101);
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_BLOCK_HASH);
        vm.recordLogs();
        ICheckpointStore.Checkpoint memory revealed =
            anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(revealed.blockHash, L1_BLOCK_HASH);
    }

    function test_revealCheckpoint_RevertWhen_CheckpointConflicts() external {
        bytes memory header =
            _syntheticHeader(21, abi.encodePacked(bytes32(uint256(0xA))), hex"0457");
        bytes memory conflicting =
            _syntheticHeader(21, abi.encodePacked(bytes32(uint256(0xB))), hex"0457");

        _recordBeaconRoot(ETNA_TIMESTAMP, keccak256(header));
        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);

        _recordBeaconRoot(ETNA_TIMESTAMP + 1, keccak256(conflicting));
        vm.expectRevert(Anchor.CheckpointConflict.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP + 1, conflicting);
    }

    function test_revealCheckpoint_RevertWhen_BeaconRootsHasNoCode() external {
        vm.etch(BEACON_ROOTS, "");
        vm.warp(ETNA_TIMESTAMP);

        vm.expectRevert(Anchor.L1BlockHashNotFound.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);
    }

    function test_revealCheckpoint_RevertWhen_RootIsZero() external {
        // Pre-Etna blocks record a zero root.
        _recordBeaconRoot(ETNA_TIMESTAMP - 1, bytes32(0));

        vm.expectRevert(Anchor.L1BlockHashNotFound.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP - 1, L1_HEADER);
    }

    function test_revealCheckpoint_RevertWhen_TimestampNotRecorded() external {
        vm.warp(ETNA_TIMESTAMP);

        vm.expectRevert(Anchor.L1BlockHashNotFound.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);
    }

    function test_revealCheckpoint_RevertWhen_RingBufferSlotOverwritten() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_BLOCK_HASH);
        // EIP-4788 keeps 8191 slots; a timestamp 8191 seconds later reuses the same slot.
        _recordBeaconRoot(ETNA_TIMESTAMP + 8191, bytes32(uint256(1)));

        vm.expectRevert(Anchor.L1BlockHashNotFound.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, L1_HEADER);
    }

    function test_revealCheckpoint_RevertWhen_HeaderDoesNotMatchHash() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, L1_BLOCK_HASH);
        bytes memory header = _syntheticHeader(21, abi.encodePacked(L1_STATE_ROOT), hex"015ef3c0");

        vm.expectRevert(Anchor.InvalidL1Header.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);
    }

    function test_revealCheckpoint_RevertWhen_TooFewFields() external {
        bytes memory header = _syntheticHeader(8, abi.encodePacked(L1_STATE_ROOT), "");
        _recordBeaconRoot(ETNA_TIMESTAMP, keccak256(header));

        vm.expectRevert(Anchor.InvalidL1Header.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);
    }

    function test_revealCheckpoint_RevertWhen_StateRootIsNot32Bytes() external {
        bytes memory header =
            _syntheticHeader(21, abi.encodePacked(bytes31(L1_STATE_ROOT)), hex"015ef3c0");
        _recordBeaconRoot(ETNA_TIMESTAMP, keccak256(header));

        vm.expectRevert(Anchor.InvalidL1Header.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);
    }

    function test_revealCheckpoint_RevertWhen_NumberExceedsUint48() external {
        bytes memory header =
            _syntheticHeader(21, abi.encodePacked(L1_STATE_ROOT), hex"01000000000000");
        _recordBeaconRoot(ETNA_TIMESTAMP, keccak256(header));

        vm.expectRevert(Anchor.InvalidL1Header.selector);
        anchor.revealCheckpoint(ETNA_TIMESTAMP, header);
    }
}
