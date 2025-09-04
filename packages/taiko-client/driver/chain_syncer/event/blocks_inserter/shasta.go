package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
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
	return errors.New("not supported in Shasta")
}

func (i *Shasta) InsertBlocksWithManifest(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	proposalManifest manifest.ProposalManifest,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	if !metadata.IsShasta() {
		return errors.New("metadata is not for Shasta fork")
	}
	if len(proposalManifest.Blocks) < 1 {
		return errors.New("invalid number of blocks")
	}

	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
		// to the channel.
		latestSeenProposal = &encoding.LastSeenProposal{TaikoProposalMetaData: metadata}
		meta               = metadata.Shasta()
	)

	log.Debug(
		"Inserting Shasta blocks to L2 execution engine",
		"proposalID", meta.GetProposal().Id,
		"invalidManifest", proposalManifest.Invalid,
		"coinbase", proposalManifest.Blocks[0].Coinbase,
	)

	var (
		parent          = proposalManifest.ParentBlock.Header()
		lastPayloadData *engine.ExecutableData
	)

	go i.sendLatestSeenProposal(latestSeenProposal)

	for j := range proposalManifest.Blocks {
		log.Debug(
			"Parent block",
			"blockID", parent.Number,
			"hash", parent.Hash(),
			"beaconSyncTriggered", i.progressTracker.Triggered(),
		)

		// TODO: To be implemented, check if the proposal is known in canonical

		// Otherwise, we need to create a new execution payload and set it as the head block in L2 EE.
		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaShasta(
			ctx,
			i.rpc,
			i.anchorConstructor,
			metadata,
			proposalManifest,
			parent,
			j,
			proposalManifest.IsLowBondProposal,
		)
		if err != nil {
			return fmt.Errorf("failed to assemble execution payload creation metadata: %w", err)
		}

		// Decompress the transactions list and try to insert a new head block to L2 EE.
		if lastPayloadData, err = createPayloadAndSetHead(
			ctx,
			i.rpc,
			&createPayloadAndSetHeadMetaData{
				createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
				Parent:                          parent,
			},
			anchorTx,
		); err != nil {
			return fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
		}

		log.Debug("Payload data", "hash", lastPayloadData.BlockHash, "txs", len(lastPayloadData.Transactions))

		// Wait till the corresponding L2 header to be existed in the L2 EE.
		if _, err := i.rpc.WaitL2Header(ctx, new(big.Int).SetUint64(lastPayloadData.Number)); err != nil {
			return fmt.Errorf("failed to wait for L2 header (%d): %w", lastPayloadData.Number, err)
		}

		log.Info(
			"🔗 New Shasta L2 block inserted",
			"blockID", lastPayloadData.Number,
			"hash", lastPayloadData.BlockHash,
			"coinbase", lastPayloadData.FeeRecipient.Hex(),
			"transactions", len(lastPayloadData.Transactions),
			"timestamp", lastPayloadData.Timestamp,
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"proposalID", meta.GetProposal().Id,
			"gasLimit", lastPayloadData.GasLimit,
			"gasUsed", lastPayloadData.GasUsed,
			"parentHash", lastPayloadData.ParentHash,
			"indexInProposal", j,
		)

		metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
	}

	// Mark the last seen proposal as not preconfirmed and send it to the channel.
	latestSeenProposal.PreconfChainReorged = true
	go i.sendLatestSeenProposal(latestSeenProposal)

	return nil
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *Shasta) InsertPreconfBlocksFromEnvelopes(
	ctx context.Context,
	envelopes []*preconf.Envelope,
	fromCache bool,
) ([]*types.Header, error) {
	panic("To be implemented")
}

// sendLatestSeenProposal sends the latest seen proposal to the channel, if it is not nil.
func (i *Shasta) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		log.Debug(
			"Sending latest seen proposal from blocksInserter",
			"proposalID", proposal.TaikoProposalMetaData.Shasta().GetProposal().Id,
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}
