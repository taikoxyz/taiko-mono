// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/iface/IPreconfSlasher.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibTrieProof.sol";
import "solady/src/utils/LibRLP.sol";

/// @title PreconfSlasher
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasher is IPreconfSlasher, EssentialContract {
    address public immutable urc;
    ITaikoInbox public immutable taikoInbox;
    uint64 public immutable l2ChainId;

    uint256[50] private __gap;

    constructor(
        address _resolver,
        address _urc,
        address _taikoInbox,
        uint64 _l2ChainId
    )
        EssentialContract(_resolver)
    {
        urc = _urc;
        taikoInbox = ITaikoInbox(_taikoInbox);
        l2ChainId = _l2ChainId;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata,
        Commitment calldata _commitment,
        address _committer,
        bytes calldata _evidence,
        address
    )
        external
        returns (uint256)
    {
        require(msg.sender == urc, SenderIsNotUrc());

        // Parse the commitment payload
        CommitmentPayload memory parsedPayload =
            abi.decode(_commitment.payload, (CommitmentPayload));

        // Validate the commitment payload
        _validateCommitmentPayload(parsedPayload);

        // Parse the violation type from the first byte
        ViolationType violationType = ViolationType(uint8(_evidence[0]));

        // Parse the evidence based on violation type
        if (violationType == ViolationType.InvalidPreconfirmation) {
            EvidenceInvalidPreconfirmation memory evidence =
                abi.decode(_evidence[1:], (EvidenceInvalidPreconfirmation));
            _validateBlockHeader(evidence.preconfedBlockHeader, parsedPayload.blockHash);
            return _slashPreconfirmationViolation(_committer, parsedPayload, evidence);
        } else if (violationType == ViolationType.InvalidEOP) {
            EvidenceInvalidEOP memory evidence = abi.decode(_evidence[1:], (EvidenceInvalidEOP));
            _validateBlockHeader(evidence.preconfedBlockHeader, parsedPayload.blockHash);
            return _slashInvalidEOP(_committer, parsedPayload, evidence);
        } else if (violationType == ViolationType.MissingEOP) {
            EvidenceMissingEOP memory evidence = abi.decode(_evidence[1:], (EvidenceMissingEOP));
            _validateBlockHeader(evidence.preconfedBlockHeader, parsedPayload.blockHash);
            return _slashMissingEOP(_committer, parsedPayload, evidence);
        }

        revert InvalidViolationType();
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc IPreconfSlasher
    function getSlashAmount() public pure returns (SlashAmount memory slashAmount) {
        return SlashAmount({
            invalidPreconf: 1 ether,
            invalidEOP: 0.5 ether,
            missingEOP: 0.5 ether,
            reorgedPreconf: 0.1 ether
        });
    }

    // Internal functions ----------------------------------------------------------------------

    function _slashPreconfirmationViolation(
        address _committer,
        CommitmentPayload memory _parsedPayload,
        EvidenceInvalidPreconfirmation memory _parsedEvidence
    )
        internal
        returns (uint256)
    {
        ITaikoInbox.Batch memory batch = taikoInbox.v4GetBatch(uint64(_parsedPayload.batchId));
        ITaikoInbox.TransitionState memory transition =
            taikoInbox.v4GetBatchVerifyingTransition(uint64(_parsedPayload.batchId));

        // Validate that the batch has been verified
        require(transition.blockHash != bytes32(0), BatchNotVerified());

        // Validate the pre-images in the evidence
        require(
            keccak256(abi.encode(_parsedEvidence.batchMetadata)) == batch.metaHash,
            InvalidBatchMetadata()
        );
        require(
            keccak256(abi.encode(_parsedEvidence.batchInfo))
                == _parsedEvidence.batchMetadata.infoHash,
            InvalidBatchInfo()
        );

        // Slash if the height of anchor block on the commitment is different from the
        // height of anchor block on the proposed block
        if (_parsedPayload.anchorId != _parsedEvidence.batchInfo.anchorBlockId) {
            uint256 slashAmount = getSlashAmount().invalidPreconf;
            emit InvalidPreconfirmationSlashed(_committer, _parsedPayload, slashAmount);
            return slashAmount;
        }

        // Check for reorgs if the committer missed the proposal
        if (_parsedEvidence.batchInfo.proposer != _committer) {
            (bool success,) = LibPreconfConstants.getBeaconBlockRootContract().staticcall(
                abi.encode(_parsedPayload.preconferSlotTimestamp)
            );

            // If the beacon block root is not available, it means that the preconfirmed block
            // was reorged out due to an L1 reorg.
            if (!success) {
                uint256 _slashAmount = getSlashAmount().reorgedPreconf;
                emit InvalidPreconfirmationSlashed(_committer, _parsedPayload, _slashAmount);
                return _slashAmount;
            }
        }

        // Ensure that the anchor block has not been reorged out
        require(
            _parsedPayload.anchorHash == _parsedEvidence.batchInfo.anchorBlockHash,
            PossibleReorgOfAnchorBlock()
        );

        // Validate that the parent on which this block was preconfirmed made it to the inbox, i.e
        // the parentHash within the preconfirmed block header must match the hash of the proposed
        // parent.
        uint256 heightOfFirstBlockInBatch =
            _parsedEvidence.batchInfo.lastBlockId - _parsedEvidence.batchInfo.blocks.length;
        if (_parsedEvidence.preconfedBlockHeader.number == heightOfFirstBlockInBatch) {
            // If the preconfirmed block is the first block in the batch, we compare the parent hash
            // against the verified block hash of the previous batch, since the "batch blockhash" is
            // basically the hash of the last block.
            ITaikoInbox.TransitionState memory parentTransition =
                taikoInbox.v4GetBatchVerifyingTransition(uint64(_parsedPayload.batchId - 1));
            require(
                parentTransition.blockHash == _parsedEvidence.preconfedBlockHeader.parentHash,
                ParentHashMismatch()
            );
        } else {
            // Else, we compare the parent hash against the blockhash present within TaikoAnchor.

            // Slot within the TaikoAnchor contract that contains the blockhash of the parent of the
            // preconfirmed block.
            bytes32 parentBlockhashSlot =
                keccak256(abi.encode(_parsedEvidence.preconfedBlockHeader.number - 1, bytes32(0)));

            LibTrieProof.verifyMerkleProof(
                transition.stateRoot,
                resolve(l2ChainId, LibStrings.B_TAIKO, false),
                parentBlockhashSlot,
                _parsedEvidence.preconfedBlockHeader.parentHash,
                _parsedEvidence.parentBlockhashProofs.accountProof,
                _parsedEvidence.parentBlockhashProofs.storageProof
            );
        }

        // Slot within the TaikoAnchor contract that contains the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        bytes32 blockhashSlot =
            keccak256(abi.encode(_parsedEvidence.preconfedBlockHeader.number, bytes32(0)));

        // Verify that `blockhashProofs` correctly proves the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        LibTrieProof.verifyMerkleProof(
            transition.stateRoot,
            resolve(l2ChainId, LibStrings.B_TAIKO, false),
            blockhashSlot,
            _parsedEvidence.blockhashProofs.value,
            _parsedEvidence.blockhashProofs.accountProof,
            _parsedEvidence.blockhashProofs.storageProof
        );

        // The preconfirmed blockhash must not match the hash of the proposed block for a
        // preconfirmation violation
        require(
            _parsedEvidence.blockhashProofs.value != _parsedPayload.blockHash,
            PreconfirmationIsValid()
        );

        uint256 __slashAmount = getSlashAmount().invalidPreconf;
        emit InvalidPreconfirmationSlashed(_committer, _parsedPayload, __slashAmount);
        return __slashAmount;
    }

    function _slashInvalidEOP(
        address _committer,
        CommitmentPayload memory _parsedPayload,
        EvidenceInvalidEOP memory _parsedEvidence
    )
        internal
        returns (uint256)
    {
        // Validate that the commitment is an EOP
        require(_parsedPayload.eop == true, NotEndOfPreconfirmation());

        ITaikoInbox.Batch memory batch = taikoInbox.v4GetBatch(uint64(_parsedPayload.batchId));

        // Slash if another block was proposed after EOP in the same batch
        if (_parsedEvidence.preconfedBlockHeader.number != batch.lastBlockId) {
            uint256 slashAmount = getSlashAmount().invalidEOP;
            emit InvalidEOPSlashed(_committer, _parsedPayload, slashAmount);
            return slashAmount;
        }

        ITaikoInbox.Batch memory nextBatch =
            taikoInbox.v4GetBatch(uint64(_parsedPayload.batchId + 1));
        require(
            keccak256(abi.encode(nextBatch.metaHash)) == _parsedEvidence.nextBatchMetadata.infoHash,
            InvalidNextBatchMetadata()
        );

        // An extra batch should be proposed after the EOP
        // We validate this by comparing the proposal timestamp to the timestamp of the preconfer's
        // lookahead slot.
        require(
            _parsedEvidence.nextBatchMetadata.proposedAt <= _parsedPayload.preconferSlotTimestamp,
            EOPIsValid()
        );

        uint256 _slashAmount = getSlashAmount().invalidEOP;
        emit InvalidEOPSlashed(_committer, _parsedPayload, _slashAmount);
        return _slashAmount;
    }

    function _slashMissingEOP(
        address _committer,
        CommitmentPayload memory _parsedPayload,
        EvidenceMissingEOP memory _parsedEvidence
    )
        internal
        returns (uint256)
    {
        // Validate that the commitment is not an EOP
        require(_parsedPayload.eop == false, EOPIsPresent());

        ITaikoInbox.Batch memory nextBatch =
            taikoInbox.v4GetBatch(uint64(_parsedPayload.batchId + 1));
        require(
            keccak256(abi.encode(nextBatch.metaHash)) == _parsedEvidence.nextBatchMetadata.infoHash,
            InvalidNextBatchMetadata()
        );

        // The block with missing EOP should be the last block in the batch and the next batch
        // should have been proposed after the lookahead slot.
        require(
            _parsedEvidence.preconfedBlockHeader.number == nextBatch.lastBlockId
                && _parsedEvidence.nextBatchMetadata.proposedAt > _parsedPayload.preconferSlotTimestamp,
            EOPIsNotMissing()
        );

        uint256 slashAmount = getSlashAmount().missingEOP;
        emit MissingEOPSlashed(_committer, _parsedPayload, slashAmount);
        return slashAmount;
    }

    function _validateCommitmentPayload(CommitmentPayload memory _payload) internal view {
        require(
            _payload.domainSeparator == LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            InvalidDomainSeparator()
        );
        require(_payload.chainId == l2ChainId, InvalidChainId());
    }

    function _validateBlockHeader(
        BlockHeader memory _header,
        bytes32 _expectedHash
    )
        internal
        pure
    {
        require(
            keccak256(LibRLP.encode(abi.encode(_header))) == _expectedHash, InvalidBlockHeader()
        );
    }
}
