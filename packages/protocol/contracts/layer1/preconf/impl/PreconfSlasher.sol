// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IPreconfSlasher.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibTrieProof.sol";
import "solady/src/utils/LibRLP.sol";

contract PreconfSlasher is IPreconfSlasher, EssentialContract {
    // Todo: owner can change this
    uint256 public slashAmountWei;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slashFromOptIn(
        Commitment calldata commitment,
        bytes calldata evidence,
        address
    )
        external
        returns (uint256)
    {
        // Parse the commitment payload and evidence
        IPreconfSlasher.CommitmentPayload memory parsedPayload =
            abi.decode(commitment.payload, (IPreconfSlasher.CommitmentPayload));
        IPreconfSlasher.Evidence memory parsedEvidence =
            abi.decode(evidence, (IPreconfSlasher.Evidence));

        ITaikoInbox taikoInbox =
            ITaikoInbox(resolve(uint64(block.chainid), LibStrings.B_TAIKO, false));

        uint64 l2ChainId = taikoInbox.v4GetConfig().chainId;

        // Validate the commitment payload
        require(
            parsedPayload.domainSeparator == LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            InvalidDomainSeparator()
        );
        require(parsedPayload.chainId == l2ChainId, InvalidChainId());
        require(
            keccak256(LibRLP.encode(abi.encode(parsedEvidence.preconfedBlockHeader)))
                == parsedPayload.blockHash,
            InvalidBlockHeader()
        );

        ITaikoInbox.Batch memory batch = taikoInbox.v4GetBatch(uint64(parsedPayload.batchId));
        ITaikoInbox.TransitionState memory transition =
            taikoInbox.v4GetBatchVerifyingTransition(uint64(parsedPayload.batchId));

        // Validate that the batch has been verified
        require(transition.blockHash != bytes32(0), BatchNotVerified());

        // Validate the pre-images in the evidence
        require(
            keccak256(abi.encode(parsedEvidence.batchMetadata)) == batch.metaHash,
            InvalidBatchMetadata()
        );
        require(
            keccak256(abi.encode(parsedEvidence.batchInfo)) == parsedEvidence.batchMetadata.infoHash,
            InvalidBatchInfo()
        );

        // Slash if the height of anchor block on the commitment is different from the
        // height of anchor block on the proposed block
        if (parsedPayload.anchorId != parsedEvidence.batchInfo.anchorBlockId) {
            return slashAmountWei;
        }

        // Todo: check if the committer and proposer do not match.
        // Contingent on https://github.com/eth-fabric/urc/issues/59.

        // Ensure that the beacon block root is available at the proposal slot timestamp i.e
        // it was not a missed slot or a reorg
        (bool success,) = LibPreconfConstants.getBeaconBlockRootContract().staticcall(
            abi.encode(parsedPayload.l1ProposalSlotTimestamp)
        );
        require(success, PossibleReorgAtProposalSlot());

        // Ensure that the anchor block has not been reorged out
        require(
            parsedPayload.anchorHash == parsedEvidence.batchInfo.anchorBlockHash,
            PossibleReorgOfAnchorBlock()
        );

        // Validate that the parent on which this block was preconfirmed made it to the inbox, i.e
        // the parentHash within the preconfirmed block header must match the hash of the proposed parent.
        uint256 heightOfFirstBlockInBatch =
            parsedEvidence.batchInfo.lastBlockId - parsedEvidence.batchInfo.blocks.length;
        if (parsedEvidence.preconfedBlockHeader.number == heightOfFirstBlockInBatch) {
            // If the preconfirmed block is the first block in the batch, we compare the parent hash
            // against the verified block hash of the previous batch, since the "batch blockhash" is
            // basically the hash of the last block.
            ITaikoInbox.TransitionState memory parentTransition =
                taikoInbox.v4GetBatchVerifyingTransition(uint64(parsedPayload.batchId - 1));
            require(
                parentTransition.blockHash == parsedEvidence.preconfedBlockHeader.parentHash,
                ParentHashMismatch()
            );
        } else {
            // Else, we compare the parent hash against the blockhash present within TaikoAnchor.

            // Slot within the TaikoAnchor contract that contains the blockhash of the parent of the
            // preconfirmed block.
            bytes32 parentBlockhashSlot =
                keccak256(abi.encode(parsedEvidence.preconfedBlockHeader.number - 1, bytes32(0)));

            LibTrieProof.verifyMerkleProof(
                transition.stateRoot,
                resolve(l2ChainId, LibStrings.B_TAIKO, false),
                parentBlockhashSlot,
                parsedEvidence.preconfedBlockHeader.parentHash,
                parsedEvidence.parentBlockhashProofs.accountProof,
                parsedEvidence.parentBlockhashProofs.storageProof
            );
        }

        // Slot within the TaikoAnchor contract that contains the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        bytes32 blockhashSlot =
            keccak256(abi.encode(parsedEvidence.preconfedBlockHeader.number, bytes32(0)));

        // Verify that `blockhashProofs` correctly proves the blockhash of the block proposed
        // at the same height as the preconfirmed block.
        LibTrieProof.verifyMerkleProof(
            transition.stateRoot,
            resolve(l2ChainId, LibStrings.B_TAIKO, false),
            blockhashSlot,
            parsedEvidence.blockhashProofs.value,
            parsedEvidence.blockhashProofs.accountProof,
            parsedEvidence.blockhashProofs.storageProof
        );

        // The preconfirmed blockhash must not match the hash of the proposed block for a 
        // preconfirmation violation
        require(
            parsedEvidence.blockhashProofs.value != parsedPayload.blockHash,
            PreconfirmationIsValid()
        );

        return slashAmountWei;
    }

    /// @dev Unused for Taiko
    function slash(
        Delegation calldata,
        Commitment calldata,
        bytes calldata,
        address
    )
        external
        returns (uint256)
    {
        return 0;
    }
}
