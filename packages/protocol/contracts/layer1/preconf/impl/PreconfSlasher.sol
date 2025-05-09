// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/iface/IPreconfSlasher.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibTrieProof.sol";
import "../libs/LibBlockHeader.sol";

/// @title PreconfSlasher
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasher is IPreconfSlasher, EssentialContract {
    using LibBlockHeader for LibBlockHeader.BlockHeader;

    address public immutable urc;
    ITaikoInbox public immutable taikoInbox;
    uint64 public immutable l2ChainId;

    uint256[50] private __gap;

    constructor(
        address _resolver,
        address _urc,
        address _taikoInbox
    )
        EssentialContract(_resolver)
    {
        urc = _urc;
        taikoInbox = ITaikoInbox(_taikoInbox);
        l2ChainId = taikoInbox.v4GetConfig().chainId;
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
        // Parse and validate the commitment payload
        CommitmentPayload memory payload = abi.decode(_commitment.payload, (CommitmentPayload));
        require(payload.chainId == l2ChainId, InvalidChainId());
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
        } else {
            revert InvalidViolationType();
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
        evidence.preconfedBlockHeader.verifyBlockHash(_payload.blockHash);

        ITaikoInbox.Batch memory batch = taikoInbox.v4GetBatch(uint64(_payload.batchId));
        ITaikoInbox.TransitionState memory transition =
            taikoInbox.v4GetBatchVerifyingTransition(uint64(_payload.batchId));

        // Validate that the batch has been verified
        require(transition.blockHash != bytes32(0), BatchNotVerified());

        // Validate the pre-images in the evidence
        require(
            keccak256(abi.encode(evidence.batchMetadata)) == batch.metaHash, InvalidBatchMetadata()
        );
        require(
            keccak256(abi.encode(evidence.batchInfo)) == evidence.batchMetadata.infoHash,
            InvalidBatchInfo()
        );

        // Slash if the height of anchor block on the commitment is different from the
        // height of anchor block on the proposed block
        if (_payload.anchorId != evidence.batchInfo.anchorBlockId) {
            return getSlashAmount().invalidPreconf;
        }

        // Check for reorgs if the committer missed the proposal
        if (evidence.batchInfo.proposer != _committer) {
            (bool success,) = LibPreconfConstants.getBeaconBlockRootContract().staticcall(
                abi.encode(_payload.preconferSlotTimestamp)
            );

            // If the beacon block root is not available, it means that the preconfirmed block
            // was reorged out due to an L1 reorg.
            if (!success) {
                return getSlashAmount().reorgedPreconf;
            }
        }

        // Ensure that the anchor block has not been reorged out
        require(
            _payload.anchorHash == evidence.batchInfo.anchorBlockHash, PossibleReorgOfAnchorBlock()
        );

        // Validate that the parent on which this block was preconfirmed made it to the inbox, i.e
        // the parentHash within the preconfirmed block header must match the hash of the proposed
        // parent.
        uint256 heightOfFirstBlockInBatch =
            evidence.batchInfo.lastBlockId - evidence.batchInfo.blocks.length;
        if (evidence.preconfedBlockHeader.number == heightOfFirstBlockInBatch) {
            // If the preconfirmed block is the first block in the batch, we compare the parent hash
            // against the verified block hash of the previous batch, since the "batch blockhash" is
            // basically the hash of the last block.
            ITaikoInbox.TransitionState memory parentTransition =
                taikoInbox.v4GetBatchVerifyingTransition(uint64(_payload.batchId - 1));
            require(
                parentTransition.blockHash == evidence.preconfedBlockHeader.parentHash,
                ParentHashMismatch()
            );
        } else {
            // Else, we compare the parent hash against the blockhash present within TaikoAnchor.

            // Slot within the TaikoAnchor contract that contains the blockhash of the parent of the
            // preconfirmed block.
            bytes32 parentBlockhashSlot =
                keccak256(abi.encode(evidence.preconfedBlockHeader.number - 1, bytes32(0)));

            LibTrieProof.verifyMerkleProof(
                transition.stateRoot,
                resolve(l2ChainId, LibStrings.B_TAIKO, false),
                parentBlockhashSlot,
                evidence.preconfedBlockHeader.parentHash,
                evidence.parentBlockhashProofs.accountProof,
                evidence.parentBlockhashProofs.storageProof
            );
        }

        // Slot within the TaikoAnchor contract that contains the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        bytes32 blockhashSlot =
            keccak256(abi.encode(evidence.preconfedBlockHeader.number, bytes32(0)));

        // Verify that `blockhashProofs` correctly proves the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        LibTrieProof.verifyMerkleProof(
            transition.stateRoot,
            resolve(l2ChainId, LibStrings.B_TAIKO, false),
            blockhashSlot,
            evidence.blockhashProofs.value,
            evidence.blockhashProofs.accountProof,
            evidence.blockhashProofs.storageProof
        );

        // The preconfirmed blockhash must not match the hash of the proposed block for a
        // preconfirmation violation
        require(evidence.blockhashProofs.value != _payload.blockHash, PreconfirmationIsValid());

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
        // Validate that the commitment is an EOP
        require(_payload.eop == true, NotEndOfPreconfirmation());

        EvidenceInvalidEOP memory evidence = abi.decode(_evidenceData[1:], (EvidenceInvalidEOP));
        evidence.preconfedBlockHeader.verifyBlockHash(_payload.blockHash);

        ITaikoInbox.Batch memory batch =
            _getBatchAndVerify(_payload.batchId, evidence.batchInfo, evidence.batchMetadata);

        if (evidence.preconfedBlockHeader.number == batch.lastBlockId) {
            // Now, we need to check if the proposer of the next batch is different from the
            // proposer of the current batch.
            _getBatchAndVerify(
                _payload.batchId + 1, evidence.nextBatchInfo, evidence.nextBatchMetadata
            );

            require(
                evidence.batchInfo.proposer == evidence.nextBatchInfo.proposer,
                NextBatchProposedByDifferentProposer()
            );
        } else {
            // Check if the block is not the last one in the batch
            ITaikoInbox.Batch memory prevBatch = taikoInbox.v4GetBatch(uint64(_payload.batchId - 1));
            require(
                evidence.preconfedBlockHeader.number > prevBatch.lastBlockId
                    && evidence.preconfedBlockHeader.number < batch.lastBlockId,
                BlockNotInBatch()
            );
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
        // Validate that the commitment is not an EOP
        require(_payload.eop == false, EOPIsPresent());

        EvidenceMissingEOP memory evidence = abi.decode(_evidenceData, (EvidenceMissingEOP));
        evidence.preconfedBlockHeader.verifyBlockHash(_payload.blockHash);

        ITaikoInbox.Batch memory batch =
            _getBatchAndVerify(_payload.batchId, evidence.batchInfo, evidence.batchMetadata);
        require(evidence.preconfedBlockHeader.number == batch.lastBlockId, BlockNotLastInBatch());

        // Validate that the next batch exists
        _getBatchAndVerify(_payload.batchId + 1, evidence.nextBatchInfo, evidence.nextBatchMetadata);
        require(
            evidence.nextBatchInfo.proposer != evidence.batchInfo.proposer,
            NextBatchProposedBySameProposer()
        );

        return getSlashAmount().missingEOP;
    }

    function _getBatchAndVerify(
        uint256 _batchId,
        ITaikoInbox.BatchInfo memory _info,
        ITaikoInbox.BatchMetadata memory _metadata
    )
        internal
        view
        returns (ITaikoInbox.Batch memory batch_)
    {
        batch_ = taikoInbox.v4GetBatch(uint64(_batchId));
        require(keccak256(abi.encode(_metadata)) == batch_.metaHash, InvalidBatchMetadata());
        require(keccak256(abi.encode(_info)) == _metadata.infoHash, InvalidBatchInfo());
    }

    // TODO(daniel): move errors to the interface
    error BlockNotLastInBatch();
    error BlockNotInBatch();
    error NextBatchProposedBySameProposer();
    error NextBatchProposedByDifferentProposer();
}
