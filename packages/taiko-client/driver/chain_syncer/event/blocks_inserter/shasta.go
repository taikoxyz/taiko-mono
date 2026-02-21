package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	shastaManifest "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Shasta is responsible for inserting Shasta blocks to the L2 execution engine.
type Shasta struct {
	rpc                  *rpc.Client
	progressTracker      *beaconsync.SyncProgressTracker
	latestSeenProposalCh chan *encoding.LastSeenProposal
	anchorConstructor    *anchorTxConstructor.AnchorTxConstructor
	mutex                sync.Mutex
}

// NewBlocksInserterShasta creates a new Shasta instance.
func NewBlocksInserterShasta(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) *Shasta {
	return &Shasta{
		rpc:                  rpc,
		progressTracker:      progressTracker,
		anchorConstructor:    anchorConstructor,
		latestSeenProposalCh: latestSeenProposalCh,
	}
}

// InsertBlocks inserts new Shasta blocks to the L2 execution engine.
func (i *Shasta) InsertBlocks(
	_ context.Context,
	_ metadata.TaikoProposalMetaData,
	_ eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	return errors.New("not supported in Shasta block inserter")
}

// InsertBlocksWithManifest inserts new Shasta blocks to the L2 execution engine based on the given derivation
// source payload.
func (i *Shasta) InsertBlocksWithManifest(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (*big.Int, error) {
	if !metadata.IsShasta() {
		return nil, errors.New("metadata is not for Shasta fork blocks")
	}

	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
		// to the channel.
		latestSeenProposal  = &encoding.LastSeenProposal{TaikoProposalMetaData: metadata}
		lastFinalizedHeader *types.Header
		meta                = metadata.Shasta()
	)

	log.Debug(
		"Inserting Shasta blocks to L2 execution engine",
		"proposalID", meta.GetEventData().Id,
		"proposer", meta.GetEventData().Proposer,
		"invalidManifest", sourcePayload.Default,
	)

	coreState, err := i.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx, BlockHash: metadata.GetRawBlockHash()})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Shasta core state: %w", err)
	}
	if coreState.LastFinalizedProposalId.Cmp(meta.GetEventData().Id) >= 0 {
		blockID, err := i.rpc.L2Engine.LastBlockIDByBatchID(ctx, coreState.LastFinalizedProposalId)
		if err == nil {
			if lastFinalizedHeader, err = i.rpc.L2.HeaderByNumber(ctx, blockID.ToInt()); err != nil {
				return nil, fmt.Errorf("failed to fetch last finalized block header (%d): %w", blockID.ToInt(), err)
			}
		} else {
			log.Warn(
				"Fail to fetch last block ID for finalized proposal, but continue inserting blocks",
				"finalizedProposalID", coreState.LastFinalizedProposalId,
				"error", err,
			)
		}
	}

	var (
		parent              = sourcePayload.ParentBlock.Header()
		lastPayloadData     *engine.ExecutableData
		batchSafeCheckpoint *verifiedCheckpoint
	)

	if lastFinalizedHeader != nil {
		batchSafeCheckpoint = &verifiedCheckpoint{
			BlockID:   lastFinalizedHeader.Number,
			BlockHash: lastFinalizedHeader.Hash(),
		}
	}

	for j := range sourcePayload.BlockPayloads {
		log.Debug(
			"Parent block",
			"blockID", parent.Number,
			"hash", parent.Hash(),
			"beaconSyncTriggered", i.progressTracker.Triggered(),
		)

		// If this is the first block in the batch, we check if the whole batch has been inserted by
		// trying to fetch the last block header from L2 EE. If it is known in canonical,
		// we can skip the rest of the blocks, and only update the L1Origin in L2 EE for each block.
		if j == 0 {
			log.Debug(
				"Checking if batch is in canonical chain",
				"batchID", meta.GetEventData().Id,
				"assignedProver", meta.GetEventData().Proposer,
				"timestamp", meta.GetTimestamp(),
				"derivationSources", len(meta.GetEventData().Sources),
				"parentNumber", parent.Number,
				"parentHash", parent.Hash(),
			)

			lastBlockHeader, isKnown, err := isKnownCanonicalBatchShasta(
				ctx,
				i.rpc,
				i.anchorConstructor,
				metadata,
				sourcePayload,
				parent,
			)
			if err != nil {
				return nil, fmt.Errorf("failed to check if Shasta batch is known in canonical chain: %w", err)
			}
			if isKnown && lastBlockHeader != nil {
				log.Info(
					"🧬 Known Shasta batch in canonical chain",
					"batchID", meta.GetEventData().Id,
					"assignedProver", meta.GetEventData().Proposer,
					"timestamp", meta.GetTimestamp(),
					"derivationSources", len(meta.GetEventData().Sources),
					"parentNumber", parent.Number,
					"parentHash", parent.Hash(),
				)

				go i.sendLatestSeenProposal(&encoding.LastSeenProposal{
					TaikoProposalMetaData: metadata,
					PreconfChainReorged:   false,
					LastBlockID:           lastBlockHeader.Number.Uint64(),
				})

				// Update the L1 origin for each block in the batch.
				if err := updateL1OriginForBatchShasta(ctx, i.rpc, parent, metadata, sourcePayload); err != nil {
					return nil, fmt.Errorf("failed to update L1 origin for batch (%d): %w", meta.GetEventData().Id, err)
				}

				return lastBlockHeader.Number, nil
			}
		}

		// inserting the blocks, and only update the L1 origin for each block in the batch.
		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaShasta(
			ctx,
			i.rpc,
			i.anchorConstructor,
			metadata,
			sourcePayload,
			parent,
			j,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to assemble execution payload creation metadata: %w", err)
		}

		// Decompress the transactions list and try to insert a new head block to L2 EE.
		if lastPayloadData, err = createPayloadAndSetHead(
			ctx,
			i.rpc,
			&createPayloadAndSetHeadMetaData{
				createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
				Parent:                          parent,
				VerifiedCheckpoint:              batchSafeCheckpoint,
			},
			anchorTx,
		); err != nil {
			return nil, fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
		}

		log.Debug("Payload data", "hash", lastPayloadData.BlockHash, "txs", len(lastPayloadData.Transactions))

		// Wait till the corresponding L2 header to be existed in the L2 EE.
		if parent, err = i.rpc.WaitL2Header(ctx, new(big.Int).SetUint64(lastPayloadData.Number)); err != nil {
			return nil, fmt.Errorf("failed to wait for L2 header (%d): %w", lastPayloadData.Number, err)
		}

		log.Info(
			"🔗 New Shasta L2 block inserted",
			"blockID", lastPayloadData.Number,
			"hash", lastPayloadData.BlockHash,
			"coinbase", lastPayloadData.FeeRecipient.Hex(),
			"transactions", len(lastPayloadData.Transactions),
			"transactionsInManifest", sourcePayload.BlockPayloads[j].Transactions.Len(),
			"timestamp", lastPayloadData.Timestamp,
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"proposalID", meta.GetEventData().Id,
			"gasLimit", lastPayloadData.GasLimit,
			"gasUsed", lastPayloadData.GasUsed,
			"parentHash", lastPayloadData.ParentHash,
			"indexInProposal", j,
		)

		latestSeenProposal.LastBlockID = lastPayloadData.Number

		metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
	}

	// Mark the last seen proposal as not preconfirmed and send it to the channel.
	latestSeenProposal.PreconfChainReorged = true
	go i.sendLatestSeenProposal(latestSeenProposal)

	return new(big.Int).SetUint64(latestSeenProposal.LastBlockID), nil
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *Shasta) InsertPreconfBlocksFromEnvelopes(
	ctx context.Context,
	envelopes []*preconf.Envelope,
	fromCache bool,
) ([]*types.Header, error) {
	i.mutex.Lock()
	defer i.mutex.Unlock()

	log.Debug(
		"Insert preconfirmation blocks from envelopes",
		"numBlocks", len(envelopes),
		"fromCache", fromCache,
	)

	headers := make([]*types.Header, len(envelopes))
	for j, envelope := range envelopes {
		header, err := i.insertPreconfBlockFromEnvelope(ctx, envelope)
		if err != nil {
			return nil, fmt.Errorf("failed to insert preconfirmation block %d: %w", envelope.Payload.BlockNumber, err)
		}
		log.Info(
			"⏰ New preconfirmation L2 block inserted",
			"blockID", header.Number,
			"hash", header.Hash(),
			"fork", "Shasta",
			"coinbase", header.Coinbase.Hex(),
			"timestamp", header.Time,
			"baseFee", utils.WeiToGWei(header.BaseFee),
			"withdrawalsHash", header.WithdrawalsHash,
			"gasLimit", header.GasLimit,
			"gasUsed", header.GasUsed,
			"parentHash", header.ParentHash,
			"fromCache", fromCache,
		)
		headers[j] = header
	}

	return headers, nil
}

// sendLatestSeenProposal sends the latest seen proposal to the channel, if it is not nil.
func (i *Shasta) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		log.Debug(
			"Sending latest seen shasta proposal from blocksInserter",
			"proposalID", proposal.TaikoProposalMetaData.Shasta().GetEventData().Id,
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}

// insertPreconfBlockFromEnvelope the inner method to insert a preconfirmation block from
// the given envelope.
func (i *Shasta) insertPreconfBlockFromEnvelope(
	ctx context.Context,
	envelope *preconf.Envelope,
) (*types.Header, error) {
	return InsertPreconfBlockFromEnvelope(ctx, i.rpc, envelope)
}
