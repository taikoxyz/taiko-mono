// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/iface/IPreconfSlasher.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibTrieProof.sol";
import "../libs/LibBlockHeader.sol";

/// @title PreconfSlasher
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasher is IPreconfSlasher, EssentialContract {
    using LibBlockHeader for LibBlockHeader.BlockHeader;

    address public immutable urc;
    address public immutable fallbackPreconfer;
    ITaikoInbox public immutable taikoInbox;
    uint64 public immutable taikoChainId;
    address public immutable taikoAnchor;

    uint256[50] private __gap;

    constructor(
        address _urc,
        address _fallbackPreconfer,
        address _taikoInbox,
        address _taikoAnchor
    ) {
        urc = _urc;
        fallbackPreconfer = _fallbackPreconfer;
        taikoInbox = ITaikoInbox(_taikoInbox);
        taikoChainId = taikoInbox.v4GetConfig().chainId;
        taikoAnchor = _taikoAnchor;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata, /*_delegation*/
        Commitment calldata _commitment,
        address _committer,
        bytes calldata _evidence,
        address /*_challenger*/
    )
        external
        nonReentrant
        onlyFrom(urc)
        returns (uint256 slashAmount_)
    {
        require(_committer != fallbackPreconfer, FallBackPreconferCannotBeSlashed());
        // Parse and validate the commitment payload
        CommitmentPayload memory payload = abi.decode(_commitment.payload, (CommitmentPayload));
        require(payload.chainId == taikoChainId, InvalidChainId());
        require(
            payload.domainSeparator == LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            InvalidDomainSeparator()
        );

        // Parse the violation type from the first byte
        ViolationType violationType = ViolationType(uint8(_evidence[0]));
        if (violationType == ViolationType.InvalidPreconfirmation) {
            slashAmount_ = _validatePreconfirmationViolation(_committer, payload, _evidence[1:]);
        } else if (violationType == ViolationType.InvalidEOP) {
            slashAmount_ = _validateInvalidEOP(payload, _evidence[1:]);
        } else if (violationType == ViolationType.MissingEOP) {
            slashAmount_ = _validateMissingEOP(payload, _evidence[1:]);
        }

        emit Slashed(_committer, violationType, payload, slashAmount_);
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc IPreconfSlasher
    function getSlashAmount() public pure returns (SlashAmount memory) {
        return SlashAmount({
            invalidPreconf: 1 ether,
            invalidEOP: 0.5 ether,
            missingEOP: 0.5 ether,
            reorgedPreconf: 0.1 ether
        });
    }

    // Internal functions ----------------------------------------------------------------------

    function _validatePreconfirmationViolation(
        address _committer,
        CommitmentPayload memory _payload,
        bytes calldata _evidenceData
    )
        internal
        view
        returns (uint256)
    {
        EvidenceInvalidPreconfirmation memory evidence =
            abi.decode(_evidenceData, (EvidenceInvalidPreconfirmation));

        LibBlockHeader.BlockHeader memory preconfed = evidence.preconfedBlockHeader;
        require(preconfed.hash() == _payload.blockHash, InvalidBlockHeader());

        _verifyBatchData(_payload.batchId, evidence.batchMetadata, evidence.batchInfo);
        ITaikoInbox.BatchInfo memory batchInfo = evidence.batchInfo;

        // Slash if the height of anchor block on the commitment is different from the
        // height of anchor block on the proposed block
        if (_payload.anchorId != batchInfo.anchorBlockId) {
            return getSlashAmount().invalidPreconf;
        }

        uint256 blockId = preconfed.number;
        require(blockId > batchInfo.lastBlockId - batchInfo.blocks.length, BlockNotInBatch());
        require(blockId <= batchInfo.lastBlockId, BlockNotInBatch());

        // Unlike anchorId, we don't penalize the preconfer if the anchorHash doesn't match. This is
        // because the anchor block could be reorganized. In such cases, the node should have
        // already discarded the preconfirmation commitment if the anchorHash doesn't align with the
        // hash of the anchor block.
        require(_payload.anchorHash == batchInfo.anchorBlockHash, PossibleReorgOfAnchorBlock());

        // Check for reorgs if the committer missed the proposal
        if (batchInfo.proposer != _committer) {
            // If the beacon block root is not available, it means that the preconfirmed block
            // was reorged out due to an L1 reorg.
            if (LibPreconfUtils.getBeaconBlockRootAt(_payload.preconferSlotTimestamp) == 0) {
                return getSlashAmount().reorgedPreconf;
            }
        }

        LibBlockHeader.BlockHeader memory actual = evidence.actualBlockHeader;
        require(actual.number == blockId, InvalidActualBlockHeader());
        // The preconfirmed blockhash must not match the hash of the proposed block for a
        // preconfirmation violation
        bytes32 actualBlockHash = actual.hash();
        require(_payload.blockHash != actualBlockHash, PreconfirmationIsValid());

        // Validate that the next batch has been verified
        ITaikoInbox.TransitionState memory transition =
            taikoInbox.v4GetBatchVerifyingTransition(uint64(_payload.batchId + 1));

        // Validate the verified blockheader
        LibBlockHeader.BlockHeader memory verified = evidence.verifiedBlockHeader;
        require(transition.blockHash == verified.hash(), InvalidVerifiedBlockHeader());

        // Validate that the parent on which this block was preconfirmed made it to the inbox, i.e
        // the parentHash within the preconfirmed block header must match the hash of the proposed
        // parent.
        LibTrieProof.verifyMerkleProof(
            verified.stateRoot,
            taikoAnchor,
            _calcBlockHashSlot(blockId - 1),
            preconfed.parentHash,
            evidence.parentBlockhashProofs.accountProof,
            evidence.parentBlockhashProofs.storageProof
        );

        // Verify that `blockhashProofs` correctly proves the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        LibTrieProof.verifyMerkleProof(
            verified.stateRoot,
            taikoAnchor,
            _calcBlockHashSlot(blockId),
            actualBlockHash,
            evidence.blockhashProofs.accountProof,
            evidence.blockhashProofs.storageProof
        );

        return getSlashAmount().invalidPreconf;
    }

    function _validateInvalidEOP(
        CommitmentPayload memory _payload,
        bytes calldata _evidenceData
    )
        internal
        view
        returns (uint256)
    {
        EvidenceInvalidEOP memory evidence = abi.decode(_evidenceData, (EvidenceInvalidEOP));
        require(evidence.preconfedBlockHeader.hash() == _payload.blockHash, InvalidBlockHeader());

        // Validate that the commitment is an EOP
        require(_payload.eop == true, NotEndOfPreconfirmation());

        ITaikoInbox.Batch memory batch =
            _verifyBatchData(_payload.batchId, evidence.batchMetadata, evidence.batchInfo);

        uint256 blockId = evidence.preconfedBlockHeader.number;
        if (blockId == batch.lastBlockId) {
            _verifyBatchData(_payload.batchId + 1, evidence.nextBatchMetadata);

            require(
                evidence.nextBatchMetadata.proposedAt <= _payload.preconferSlotTimestamp,
                NextBatchProposedInNextPreconfWindow()
            );
        } else {
            uint256 firstBlockId = batch.lastBlockId + 1 - evidence.batchInfo.blocks.length;
            require(blockId >= firstBlockId && blockId < batch.lastBlockId, BlockNotInBatch());
        }

        return getSlashAmount().invalidEOP;
    }

    function _validateMissingEOP(
        CommitmentPayload memory _payload,
        bytes calldata _evidenceData
    )
        internal
        view
        returns (uint256)
    {
        EvidenceMissingEOP memory evidence = abi.decode(_evidenceData, (EvidenceMissingEOP));
        require(evidence.preconfedBlockHeader.hash() == _payload.blockHash, InvalidBlockHeader());

        // Validate that the commitment is not an EOP
        require(_payload.eop == false, EOPIsPresent());

        ITaikoInbox.Batch memory batch = _verifyBatchData(_payload.batchId, evidence.batchMetadata);
        require(evidence.preconfedBlockHeader.number == batch.lastBlockId, BlockNotLastInBatch());

        _verifyBatchData(_payload.batchId + 1, evidence.nextBatchMetadata);

        require(
            evidence.nextBatchMetadata.proposedAt > _payload.preconferSlotTimestamp,
            NextBatchProposedInTheSamePreconfWindow()
        );

        return getSlashAmount().missingEOP;
    }

    function _verifyBatchData(
        uint256 _batchId,
        ITaikoInbox.BatchMetadata memory _metadata,
        ITaikoInbox.BatchInfo memory _info
    )
        internal
        view
        returns (ITaikoInbox.Batch memory batch_)
    {
        batch_ = _verifyBatchData(_batchId, _metadata);
        require(keccak256(abi.encode(_info)) == _metadata.infoHash, InvalidBatchInfo());
    }

    function _verifyBatchData(
        uint256 _batchId,
        ITaikoInbox.BatchMetadata memory _metadata
    )
        internal
        view
        returns (ITaikoInbox.Batch memory batch_)
    {
        batch_ = taikoInbox.v4GetBatch(uint64(_batchId));
        require(keccak256(abi.encode(_metadata)) == batch_.metaHash, InvalidBatchMetadata());
    }

    function _calcBlockHashSlot(uint256 _blockId) internal pure returns (bytes32) {
        // The mapping is in the 251st slot
        return keccak256(abi.encode(_blockId, bytes32(uint256(251))));
    }
}
