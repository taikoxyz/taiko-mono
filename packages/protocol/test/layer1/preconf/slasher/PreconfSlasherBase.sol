// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./data/Evidence.sol";
import "./data/BlockHeader.sol";
import "test/shared/CommonTest.sol";
import "test/layer1/preconf/mocks/MockTaikoInbox.sol";
import "test/layer1/preconf/mocks/MockBeaconBlockRoot.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/impl/PreconfSlasher.sol";
import "src/layer1/preconf/libs/LibBlockHeader.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/libs/LibNetwork.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "@eth-fabric/urc/IRegistry.sol";

contract PreconfSlasherBase is CommonTest {
    using LibBlockHeader for LibBlockHeader.BlockHeader;

    /// @notice This is used to specify the position of a block inserted within a mock batch
    enum BlockPosition {
        PREV_BATCH,
        START_OF_BATCH,
        MIDDLE_OF_BATCH,
        END_OF_BATCH,
        NEXT_BATCH
    }

    PreconfSlasher internal preconfSlasher;
    MockTaikoInbox internal taikoInbox;

    LibBlockHeader.BlockHeader internal actualBlockHeader;
    LibBlockHeader.BlockHeader internal verifiedBlockHeader;

    ITaikoInbox.BatchInfo internal _cachedBatchInfo;
    ITaikoInbox.BatchMetadata internal _cachedBatchMetadata;
    ITaikoInbox.BatchMetadata internal _cachedNextBatchMetadata;

    address internal urc = vm.addr(uint256(bytes32("urc")));
    address internal fallbackPreconfer = vm.addr(uint256(bytes32("fallbackPreconfer")));
    address internal preconfSigner = vm.addr(uint256(bytes32("preconfSigner")));
    uint64 internal correctAnchorBlockId = uint64(uint256(keccak256("correct_anchor_id")));
    bytes32 internal correctAnchorBlockHash = bytes32("correct_anchor_hash");
    uint64 internal preconferSlotTimestamp = uint64(uint256(keccak256("preconfer_slot_timestamp")));
    bytes4 internal emptyRevert = bytes4(0xffffffff);

    function setUpOnEthereum() internal virtual override {
        taikoInbox = new MockTaikoInbox(LibNetwork.TAIKO_MAINNET);

        // Load the beacon block root precompile
        vm.etch(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT, address(new MockBeaconBlockRoot()).code
        );

        // We are using Taiko's mainnet block data for simulations, thus we use the
        // mainnet anchor contract address
        address taikoAnchor = 0x1670000000000000000000000000000000010001;

        address preconfSlasherAddress = deploy({
            name: "preconf_slasher",
            impl: address(new PreconfSlasher(urc, fallbackPreconfer, address(taikoInbox), taikoAnchor)),
            data: ""
        });
        preconfSlasher = PreconfSlasher(preconfSlasherAddress);

        actualBlockHeader = BlockHeader.getActualBlockHeader();
        verifiedBlockHeader = BlockHeader.getVerifiedBlockHeader();
    }

    // Modifiers
    // -------------------------------------------------------------------

    modifier InsertBatchAndTransition(BlockPosition _blockPosition, address _proposer) {
        _insertBatch(1, uint64(actualBlockHeader.number), _blockPosition, _proposer);
        _insertTransition(2, verifiedBlockHeader.hash());
        _;
    }

    // Internal Helpers
    // -------------------------------------------------------------------

    function _insertBatch(
        uint64 _batchId,
        uint64 _blockId,
        BlockPosition _blockPosition,
        address _proposer
    )
        internal
    {
        uint64 numBlocks = 10;

        _cachedBatchInfo.anchorBlockId = correctAnchorBlockId;
        _cachedBatchInfo.anchorBlockHash = correctAnchorBlockHash;
        _cachedBatchInfo.proposer = _proposer;
        for (uint256 i; i < numBlocks; ++i) {
            ITaikoInbox.BlockParams memory blockParams;
            _cachedBatchInfo.blocks.push(blockParams);
        }

        if (_blockPosition == BlockPosition.PREV_BATCH) {
            _cachedBatchInfo.lastBlockId = _blockId + numBlocks;
        } else if (_blockPosition == BlockPosition.START_OF_BATCH) {
            _cachedBatchInfo.lastBlockId = _blockId + numBlocks - 1;
        } else if (_blockPosition == BlockPosition.MIDDLE_OF_BATCH) {
            _cachedBatchInfo.lastBlockId = _blockId + (numBlocks / 2);
        } else if (_blockPosition == BlockPosition.END_OF_BATCH) {
            _cachedBatchInfo.lastBlockId = _blockId;
        } else if (_blockPosition == BlockPosition.NEXT_BATCH) {
            _cachedBatchInfo.lastBlockId = _blockId - 1;
        }

        _cachedBatchMetadata.infoHash = keccak256(abi.encode(_cachedBatchInfo));

        ITaikoInbox.Batch memory batch;
        batch.metaHash = keccak256(abi.encode(_cachedBatchMetadata));
        batch.batchId = _batchId;
        batch.lastBlockId = _cachedBatchInfo.lastBlockId;

        taikoInbox.setBatch(_batchId, batch);
    }

    function _insertNextBatch(uint64 _batchId, uint64 _proposedAt) internal {
        _cachedNextBatchMetadata.proposedAt = _proposedAt;

        ITaikoInbox.Batch memory batch;
        batch.batchId = _batchId;
        batch.metaHash = keccak256(abi.encode(_cachedNextBatchMetadata));

        taikoInbox.setBatch(_batchId, batch);
    }

    function _insertTransition(uint64 _batchId, bytes32 _blockHash) internal {
        ITaikoInbox.TransitionState memory transition;
        transition.blockHash = _blockHash;

        taikoInbox.setTransition(_batchId, transition);
    }

    function _buildPreconfirmationCommitment(
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader
    )
        internal
        view
        returns (ISlasher.Commitment memory)
    {
        return _buildPreconfirmationCommitment(
            LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            LibNetwork.TAIKO_MAINNET,
            correctAnchorBlockId,
            correctAnchorBlockHash,
            false,
            _preconfedBlockHeader
        );
    }

    function _buildPreconfirmationCommitment(
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader,
        bool _eop
    )
        internal
        view
        returns (ISlasher.Commitment memory)
    {
        return _buildPreconfirmationCommitment(
            LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            LibNetwork.TAIKO_MAINNET,
            correctAnchorBlockId,
            correctAnchorBlockHash,
            _eop,
            _preconfedBlockHeader
        );
    }

    function _buildPreconfirmationCommitment(
        bytes32 _domainSeparator,
        uint64 _chainId,
        uint64 _anchorId,
        bytes32 _anchorHash,
        bool _eop,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader
    )
        internal
        view
        returns (ISlasher.Commitment memory)
    {
        IPreconfSlasher.CommitmentPayload memory commitmentPayload;
        commitmentPayload.domainSeparator = _domainSeparator;
        commitmentPayload.chainId = _chainId;
        commitmentPayload.anchorId = _anchorId;
        commitmentPayload.anchorHash = _anchorHash;
        commitmentPayload.preconferSlotTimestamp = preconferSlotTimestamp;
        commitmentPayload.batchId = 1;
        commitmentPayload.blockHash = _preconfedBlockHeader.hash();
        commitmentPayload.eop = _eop;

        ISlasher.Commitment memory commitment;
        commitment.payload = abi.encode(commitmentPayload);
        commitment.slasher = address(preconfSlasher);

        return commitment;
    }

    function _slashViolatedPreconfirmation(
        ISlasher.Commitment memory _commitment,
        address _committer,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader
    )
        internal
        returns (uint256)
    {
        return
            _slashViolatedPreconfirmation(_commitment, _committer, _preconfedBlockHeader, bytes4(0));
    }

    function _slashViolatedPreconfirmation(
        ISlasher.Commitment memory _commitment,
        address _committer,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader,
        bytes4 _revertData
    )
        internal
        returns (uint256)
    {
        // We leave the delegation empty as it is not required
        ISlasher.Delegation memory delegation;

        IPreconfSlasher.EvidenceInvalidPreconfirmation memory evidence;
        evidence.preconfedBlockHeader = _preconfedBlockHeader;
        evidence.batchInfo = _cachedBatchInfo;
        evidence.batchMetadata = _cachedBatchMetadata;
        evidence.actualBlockHeader = actualBlockHeader;
        evidence.verifiedBlockHeader = verifiedBlockHeader;
        evidence.blockhashProofs = Evidence.getBlockHashProof();
        evidence.parentBlockhashProofs = Evidence.getParentBlockHashProof();

        if (_revertData == emptyRevert) {
            vm.expectRevert();
        } else if (_revertData != bytes4(0)) {
            vm.expectRevert(abi.encodeWithSelector(_revertData));
        }

        uint256 slashedAmount = preconfSlasher.slash(
            delegation,
            _commitment,
            _committer,
            bytes.concat(
                bytes1(uint8(IPreconfSlasher.ViolationType.InvalidPreconfirmation)),
                abi.encode(evidence)
            ),
            address(0) // Challenger is not required
        );

        return slashedAmount;
    }

    function _slashInvalidEOP(
        ISlasher.Commitment memory _commitment,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader
    )
        internal
        returns (uint256)
    {
        return _slashInvalidEOP(_commitment, _preconfedBlockHeader, bytes4(0));
    }

    function _slashInvalidEOP(
        ISlasher.Commitment memory _commitment,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader,
        bytes4 _revertData
    )
        internal
        returns (uint256)
    {
        // We leave the delegation empty as it is not required
        ISlasher.Delegation memory delegation;

        IPreconfSlasher.EvidenceInvalidEOP memory evidence;
        evidence.preconfedBlockHeader = _preconfedBlockHeader;
        evidence.batchInfo = _cachedBatchInfo;
        evidence.batchMetadata = _cachedBatchMetadata;
        evidence.nextBatchMetadata = _cachedNextBatchMetadata;

        if (_revertData == emptyRevert) {
            vm.expectRevert();
        } else if (_revertData != bytes4(0)) {
            vm.expectRevert(abi.encodeWithSelector(_revertData));
        }

        uint256 slashedAmount = preconfSlasher.slash(
            delegation,
            _commitment,
            address(0), // Committer is not required
            bytes.concat(
                bytes1(uint8(IPreconfSlasher.ViolationType.InvalidEOP)), abi.encode(evidence)
            ),
            address(0) // Challenger is not required
        );

        return slashedAmount;
    }

    function _slashMissingEOP(
        ISlasher.Commitment memory _commitment,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader
    )
        internal
        returns (uint256)
    {
        return _slashMissingEOP(_commitment, _preconfedBlockHeader, bytes4(0));
    }

    function _slashMissingEOP(
        ISlasher.Commitment memory _commitment,
        LibBlockHeader.BlockHeader memory _preconfedBlockHeader,
        bytes4 _revertData
    )
        internal
        returns (uint256)
    {
        // We leave the delegation empty as it is not required
        ISlasher.Delegation memory delegation;

        IPreconfSlasher.EvidenceMissingEOP memory evidence;
        evidence.preconfedBlockHeader = _preconfedBlockHeader;
        evidence.batchMetadata = _cachedBatchMetadata;
        evidence.nextBatchMetadata = _cachedNextBatchMetadata;

        if (_revertData == emptyRevert) {
            vm.expectRevert();
        } else if (_revertData != bytes4(0)) {
            vm.expectRevert(abi.encodeWithSelector(_revertData));
        }

        uint256 slashedAmount = preconfSlasher.slash(
            delegation,
            _commitment,
            address(0), // Committer is not required
            bytes.concat(
                bytes1(uint8(IPreconfSlasher.ViolationType.MissingEOP)), abi.encode(evidence)
            ),
            address(0) // Challenger is not required
        );

        return slashedAmount;
    }
}
