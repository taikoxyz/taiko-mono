// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";

/// @title EtnaLandTestBase
/// @notice Lands grid batches on an Inbox set up like the Lean example chain
/// (`Etna.Design.Examples`): genesis hash `bytes32(100)`, initialized at L1 block 2 with genesis
/// cutoff 1, three forced inclusions saved, L1 at block 11 with reference block 10 hashing to
/// `bytes32(999)`, and every landing proving snapshot 4.
/// @dev The committed chain is the Lean `cutAt` table extended to every height: EL hash 100 + x,
/// Comet hash 200 + x (0 at x = 0), forced inclusion cursor x / 6 and state root 300 + x. A suite
/// that lands beyond height 18 must save enough forced inclusions or lower the input's head.
/// `_statement` and `_cutHash` rebuild appendix A with flat `abi.encode`, independently of the
/// contract; they read only the stored generation and committee configuration hash and the
/// immutable L2 chain id and registry through the Inbox getters.
abstract contract EtnaLandTestBase is EtnaInboxTestBase {
    /// @dev `K`, the landing grid interval.
    uint256 internal constant K = 6;

    /// @dev The proof bytes of every landing; the mock verifier ignores them.
    bytes internal constant PROOF = "etna proof";

    /// @dev The Lean example's forced inclusions saved before landing.
    uint256 internal constant LEAN_FORCED_INCLUSIONS = 3;

    /// @dev The Lean example's reference block and its hash.
    uint256 internal constant LEAN_REFERENCE_BLOCK = 10;
    bytes32 internal constant LEAN_REFERENCE_HASH = bytes32(uint256(999));

    /// @dev The selection snapshot every Lean example landing proves.
    uint256 internal constant LEAN_SNAPSHOT = 4;

    /// @dev The reference block of the inputs `_input` builds, and the hash `_statement` binds.
    uint256 internal l1ReferenceBlockNumber;
    bytes32 internal l1ReferenceBlockHash;

    /// @dev The versioned blob hashes attached to every landing, in index order.
    bytes32[] internal blobHashes;

    function setUp() public virtual override {
        super.setUp();
        _upgradeAndInit(inboxImpl, _leanInitParams());
        vm.deal(Alice, 1000 ether);
        _saveForcedInclusions(LEAN_FORCED_INCLUSIONS);
        vm.roll(LEAN_REFERENCE_BLOCK + 1);
        _setReference(LEAN_REFERENCE_BLOCK, LEAN_REFERENCE_HASH);
        _setBlobCount(2);
    }

    /// @dev `setUp` initializes the Inbox itself, with the Lean genesis hash.
    function _initializeOnSetUp() internal pure virtual override returns (bool) {
        return false;
    }

    // ---------------------------------------------------------------
    // The committed chain
    // ---------------------------------------------------------------

    /// @dev The cut at height `_x`: EL hash, Comet hash and forced inclusion cursor.
    function _cut(uint256 _x)
        internal
        pure
        virtual
        returns (bytes32 el_, bytes32 comet_, uint256 head_)
    {
        return (bytes32(100 + _x), _x == 0 ? bytes32(0) : bytes32(200 + _x), _x / K);
    }

    /// @dev The EL state root at height `_x`.
    function _stateRoot(uint256 _x) internal pure virtual returns (bytes32) {
        return bytes32(300 + _x);
    }

    /// @dev `cutLeaf(x) = keccak256(abi.encode(x, blockHash, cometHash, forcedHead))`.
    function _leafOf(
        uint256 _x,
        bytes32 _el,
        bytes32 _comet,
        uint256 _head
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_x, _el, _comet, _head));
    }

    /// @dev The cut leaf of the committed chain at height `_x`.
    function _leaf(uint256 _x) internal pure returns (bytes32) {
        (bytes32 el, bytes32 comet, uint256 head) = _cut(_x);
        return _leafOf(_x, el, comet, head);
    }

    /// @dev The committed chain's leaves at the grid points strictly between `_p` and `_h`.
    function _leaves(uint256 _p, uint256 _h) internal pure returns (bytes32[] memory leaves_) {
        leaves_ = new bytes32[]((_h - _p) / K - 1);
        for (uint256 i; i < leaves_.length; ++i) {
            leaves_[i] = _leaf(_p + K * (i + 1));
        }
    }

    /// @dev The inputs landing the committed chain's `(_p, _h]` with the current reference block
    /// and snapshot 4.
    function _input(uint256 _p, uint256 _h) internal view returns (IEtnaInbox.LandInput memory) {
        (bytes32 el, bytes32 comet, uint256 head) = _cut(_h);
        return IEtnaInbox.LandInput({
            parentHeight: _p,
            lastHeight: _h,
            lastBlockHash: el,
            lastCometHash: comet,
            lastStateRoot: _stateRoot(_h),
            l1ReferenceBlockNumber: l1ReferenceBlockNumber,
            forcedInclusionHead: head,
            activeCommitteeSnapshot: LEAN_SNAPSHOT
        });
    }

    // ---------------------------------------------------------------
    // Appendix A, rebuilt
    // ---------------------------------------------------------------

    /// @dev `cutHash = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"), generation, p, h,
    /// keccak256(abi.encodePacked(leaves))))` under the stored generation.
    function _cutHash(
        IEtnaInbox.LandInput memory _in,
        bytes32[] memory _leafList
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32("ETNA_LAND_CUTS_V1"),
                uint256(_inbox().recoveryGeneration()),
                _in.parentHeight,
                _in.lastHeight,
                keccak256(abi.encodePacked(_leafList))
            )
        );
    }

    /// @dev The landing statement: keccak256 of the 21 appendix A words (672 bytes), with
    /// parentHash, parentCometHash and headBefore from `_origin`, the reference hash
    /// `l1ReferenceBlockHash` and the hash of `blobHashes`.
    function _statement(
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin,
        bytes32 _cutHashValue
    )
        internal
        view
        returns (bytes32)
    {
        bytes memory preimage = bytes.concat(
            _statementWords0To6(_in),
            _statementWords7To13(_in, _origin),
            _statementWords14To20(_in, _origin, _cutHashValue)
        );
        assertEq(preimage.length, 672, "21 statement words");
        return keccak256(preimage);
    }

    // ---------------------------------------------------------------
    // Landing
    // ---------------------------------------------------------------

    /// @dev Bob lands the committed chain's `(_p, _h]` with its honest leaves.
    function _land(uint256 _p, uint256 _h) internal returns (IEtnaInbox.LandInput memory input_) {
        input_ = _input(_p, _h);
        _land(input_, _leaves(_p, _h));
    }

    /// @dev Bob lands `_in` with `_leafList`, expecting `verifyProof(0, statement, PROOF)` with
    /// the statement over `landings(p)` and `Landed(p, c, h, cutHash, snapshot, 1)` with `c` the
    /// checkpoint height before the call. The call expectation is not counted, so a suite may land
    /// the same transaction again after `vm.revertToState`.
    function _land(
        IEtnaInbox.LandInput memory _in,
        bytes32[] memory _leafList
    )
        internal
        returns (bytes32 statement_)
    {
        bytes32 cutHash = _cutHash(_in, _leafList);
        statement_ = _statement(_in, _inbox().landings(_in.parentHeight), cutHash);
        uint256 c = _inbox().lastCheckpoint().height;

        vm.blobhashes(blobHashes);
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statement_, PROOF))
        );
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.Landed(
            _in.parentHeight, c, _in.lastHeight, cutHash, _in.activeCommitteeSnapshot, 1
        );
        vm.prank(Bob);
        _inbox().land(_in, _leafList, PROOF);
    }

    /// @dev Expects Bob's landing of `_in` with `_leafList` to revert with `_selector`, leaving
    /// the generation, checkpoint, queue pointers, snapshot and `landings(h)` unchanged.
    function _expectLandRevert(
        IEtnaInbox.LandInput memory _in,
        bytes32[] memory _leafList,
        bytes4 _selector
    )
        internal
    {
        bytes32[9] memory before = _landingState(_in.lastHeight);
        vm.blobhashes(blobHashes);
        vm.expectRevert(_selector);
        vm.prank(Bob);
        _inbox().land(_in, _leafList, PROOF);
        bytes32[9] memory afterRevert = _landingState(_in.lastHeight);
        for (uint256 i; i < before.length; ++i) {
            assertEq(afterRevert[i], before[i], "no state change");
        }
    }

    // ---------------------------------------------------------------
    // Setup helpers
    // ---------------------------------------------------------------

    /// @dev The default genesis inputs with the committed chain's block-0 hash.
    function _leanInitParams() internal view returns (IEtnaInbox.InitParams memory params_) {
        params_ = _defaultInitParams();
        (params_.genesisBlockHash,,) = _cut(0);
    }

    /// @dev Uses L1 block `_number`, whose `blockhash` becomes `_hash`, as the reference block.
    function _setReference(uint256 _number, bytes32 _hash) internal {
        (l1ReferenceBlockNumber, l1ReferenceBlockHash) = (_number, _hash);
        if (_number < block.number) vm.setBlockhash(_number, _hash);
    }

    /// @dev Attaches `_count` distinct versioned blob hashes to every later landing.
    function _setBlobCount(uint256 _count) internal {
        delete blobHashes;
        for (uint256 i; i < _count; ++i) {
            blobHashes.push(_blobHash(i));
        }
    }

    /// @dev A versioned (0x01-prefixed) blob hash for index `_i`.
    function _blobHash(uint256 _i) internal pure returns (bytes32) {
        return bytes32((uint256(1) << 248) | (uint256(keccak256(abi.encode("etna blob", _i))) >> 8));
    }

    /// @dev Alice saves `_count` forced inclusions, paying exactly the current fee for each.
    function _saveForcedInclusions(uint256 _count) internal returns (uint256 feesWei_) {
        for (uint256 i; i < _count; ++i) {
            uint256 fee = uint256(_inbox().getCurrentForcedInclusionFee()) * 1 gwei;
            (, uint48 tail) = _inbox().getForcedInclusionState();
            vm.prank(Alice);
            _inbox().saveForcedInclusion{ value: fee }(abi.encodePacked("forced", uint256(tail)));
            feesWei_ += fee;
        }
    }

    /// @dev Upgrades the Inbox proxy to a fresh implementation with `maxBatchBlocks` set to
    /// `_maxBatchBlocks` and the other immutables unchanged.
    function _upgradeWithMaxBatchBlocks(uint64 _maxBatchBlocks) internal {
        IEtnaInbox.Config memory config = _defaultConfig();
        config.maxBatchBlocks = _maxBatchBlocks;
        _inbox().upgradeTo(address(_newInboxImpl(config)));
    }

    // ---------------------------------------------------------------
    // Storage helpers
    // ---------------------------------------------------------------

    function _inbox() internal view returns (EtnaInbox) {
        return EtnaInbox(inboxProxy);
    }

    function _inboxWord(uint256 _slot) internal view returns (bytes32) {
        return vm.load(inboxProxy, bytes32(_slot));
    }

    function _storeInboxWord(uint256 _slot, bytes32 _word) internal {
        vm.store(inboxProxy, bytes32(_slot), _word);
    }

    /// @dev The first of the three slot 285 words of `landings[_height]`.
    function _landingSlot(uint256 _height) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_height, LANDINGS_SLOT)));
    }

    /// @dev The first of the three slot 290 words of `origins[_generation]`.
    function _originSlot(uint256 _generation) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_generation, ORIGINS_SLOT)));
    }

    /// @dev Word 1 of a landing record: parentHeight, generation and head, 48 bits each from the
    /// least-significant bit.
    function _landingWord1(
        uint256 _parentHeight,
        uint256 _generation,
        uint256 _head
    )
        internal
        pure
        returns (bytes32)
    {
        return bytes32(_parentHeight | (_generation << 48) | (_head << 96));
    }

    /// @dev Writes `landings[_height]` directly.
    function _plantLanding(uint256 _height, IEtnaInbox.Landing memory _landing) internal {
        uint256 slot = _landingSlot(_height);
        _storeInboxWord(
            slot, _landingWord1(_landing.parentHeight, _landing.generation, _landing.head)
        );
        _storeInboxWord(slot + 1, _landing.elHash);
        _storeInboxWord(slot + 2, _landing.cometHash);
    }

    /// @dev Writes `_generation` as the recovery generation with origin `(_startHeight, block.number,
    /// block.timestamp)`, as a recovery at `_startHeight` would.
    function _plantGeneration(uint256 _generation, uint256 _startHeight) internal {
        _storeInboxWord(RECOVERY_GENERATION_SLOT, bytes32(_generation));
        uint256 slot = _originSlot(_generation);
        _storeInboxWord(slot, bytes32(_startHeight));
        _storeInboxWord(slot + 1, bytes32(block.number));
        _storeInboxWord(slot + 2, bytes32(block.timestamp));
    }

    /// @dev Writes the forced inclusion queue pointers (slot 281).
    function _plantQueue(uint256 _head, uint256 _tail) internal {
        _storeInboxWord(FORCED_INCLUSION_HEAD_TAIL_SLOT, bytes32(_head | (_tail << 48)));
    }

    /// @dev Checks `landings(_height)` through the getter and its three raw slot 285 words.
    function _assertLanding(uint256 _height, IEtnaInbox.Landing memory _expected) internal view {
        IEtnaInbox.Landing memory landing = _inbox().landings(_height);
        assertEq(landing.parentHeight, _expected.parentHeight, "landing parentHeight");
        assertEq(landing.generation, _expected.generation, "landing generation");
        assertEq(landing.head, _expected.head, "landing head");
        assertEq(landing.elHash, _expected.elHash, "landing elHash");
        assertEq(landing.cometHash, _expected.cometHash, "landing cometHash");
        uint256 slot = _landingSlot(_height);
        assertEq(
            _inboxWord(slot),
            _landingWord1(_expected.parentHeight, _expected.generation, _expected.head),
            "slot 285 word 1"
        );
        assertEq(_inboxWord(slot + 1), _expected.elHash, "slot 285 word 2");
        assertEq(_inboxWord(slot + 2), _expected.cometHash, "slot 285 word 3");
    }

    /// @dev Checks the checkpoint through the getter and slots 270/271.
    function _assertCheckpoint(uint256 _height, bytes32 _blockHash) internal view {
        IEtnaInbox.LandedCheckpoint memory checkpoint = _inbox().lastCheckpoint();
        assertEq(checkpoint.height, _height, "checkpoint height");
        assertEq(checkpoint.blockHash, _blockHash, "checkpoint hash");
        assertEq(uint256(_inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT)), _height, "slot 270");
        assertEq(_inboxWord(LAST_CHECKPOINT_HASH_SLOT), _blockHash, "slot 271");
    }

    /// @dev Checks the queue pointers through the getter.
    function _assertQueue(uint256 _head, uint256 _tail) internal view {
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(head, _head, "queue head");
        assertEq(tail, _tail, "queue tail");
    }

    // ---------------------------------------------------------------
    // Private helpers
    // ---------------------------------------------------------------

    /// @dev Slots 268-271, 281, 284 and the three words of `landings[_height]`.
    function _landingState(uint256 _height) private view returns (bytes32[9] memory words_) {
        words_[0] = _inboxWord(RECOVERY_GENERATION_SLOT);
        words_[1] = _inboxWord(COMMITTEE_CONFIG_HASH_SLOT);
        words_[2] = _inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT);
        words_[3] = _inboxWord(LAST_CHECKPOINT_HASH_SLOT);
        words_[4] = _inboxWord(FORCED_INCLUSION_HEAD_TAIL_SLOT);
        words_[5] = _inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT);
        uint256 slot = _landingSlot(_height);
        words_[6] = _inboxWord(slot);
        words_[7] = _inboxWord(slot + 1);
        words_[8] = _inboxWord(slot + 2);
    }

    /// @dev Statement words 0-6: tag, L1 chain id, L2 chain id, Inbox, registry, generation, p.
    function _statementWords0To6(IEtnaInbox.LandInput memory _in)
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            bytes32("TAIKO_ETNA_LAND_V1"),
            block.chainid,
            uint256(_inbox().l2ChainId()),
            inboxProxy,
            _inbox().stakingRegistry(),
            uint256(_inbox().recoveryGeneration()),
            _in.parentHeight
        );
    }

    /// @dev Statement words 7-13: parentHash, parentCometHash, committeeConfigHash, h,
    /// lastBlockHash, lastCometHash, lastStateRoot.
    function _statementWords7To13(
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin
    )
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            _origin.elHash,
            _origin.cometHash,
            _inbox().committeeConfigHash(),
            _in.lastHeight,
            _in.lastBlockHash,
            _in.lastCometHash,
            _in.lastStateRoot
        );
    }

    /// @dev Statement words 14-20: reference number and hash, blob hashes hash, headBefore,
    /// headAfter, activeCommitteeSnapshot, cutHash.
    function _statementWords14To20(
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin,
        bytes32 _cutHashValue
    )
        private
        view
        returns (bytes memory)
    {
        bytes32[] memory blobs = blobHashes;
        return abi.encode(
            _in.l1ReferenceBlockNumber,
            l1ReferenceBlockHash,
            keccak256(abi.encodePacked(blobs)),
            uint256(_origin.head),
            _in.forcedInclusionHead,
            _in.activeCommitteeSnapshot,
            _cutHashValue
        );
    }
}
