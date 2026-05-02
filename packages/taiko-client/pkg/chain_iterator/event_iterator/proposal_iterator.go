package eventiterator

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// isNonCanonicalLog reports whether a log was emitted by a non-canonical L1
// block — either because it has been marked Removed by the RPC, or because the
// canonical header at the log's block number has a different hash (i.e. the
// log is from an orphaned block whose hash the RPC may still serve directly).
func isNonCanonicalLog(raw types.Log, canonicalHeader *types.Header) bool {
	return raw.Removed || canonicalHeader.Hash() != raw.BlockHash
}

// EndProposalEventIterFunc ends the current iteration.
type EndProposalEventIterFunc func()

// OnProposalEvent represents the callback function which will be called
// when a proposal event is iterated.
type OnProposalEvent func(
	context.Context,
	metadata.TaikoProposalMetaData,
	EndProposalEventIterFunc,
) error

// ProposalIterator iterates the emitted proposal events in the chain,
// with the awareness of reorganization.
type ProposalIterator struct {
	blockBatchIterator *chainIterator.BlockBatchIterator
	isEnd              bool
	// sawNonCanonical records whether the last Iter call observed a Proposed
	// event whose block hash didn't match the canonical hash at its block
	// number (or whose Removed flag was set). When true, the caller MUST NOT
	// commit the iterated range — the L1 RPC's log index is out of sync with
	// its head for that range and may also be hiding canonical logs.
	sawNonCanonical bool
}

// ProposalIteratorConfig represents the configs of a proposal event iterator.
type ProposalIteratorConfig struct {
	RpcClient             *rpc.Client
	MaxBlocksReadPerEpoch *uint64
	StartHeight           *big.Int
	EndHeight             *big.Int
	OnProposalEvent       OnProposalEvent
	BlockConfirmations    *uint64
}

// NewProposalIterator creates a new instance of a proposal event iterator.
func NewProposalIterator(ctx context.Context, cfg *ProposalIteratorConfig) (*ProposalIterator, error) {
	if cfg.RpcClient == nil || cfg.RpcClient.L1 == nil {
		return nil, errors.New("invalid RPC client")
	}

	if cfg.OnProposalEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := new(ProposalIterator)

	// Initialize the inner block iterator.
	blockIterator, err := chainIterator.NewBlockBatchIterator(ctx, &chainIterator.BlockBatchIteratorConfig{
		Client:                cfg.RpcClient.L1,
		MaxBlocksReadPerEpoch: cfg.MaxBlocksReadPerEpoch,
		StartHeight:           cfg.StartHeight,
		EndHeight:             cfg.EndHeight,
		BlockConfirmations:    cfg.BlockConfirmations,
		OnBlocks: assembleProposalIteratorCallback(
			cfg.RpcClient,
			cfg.OnProposalEvent,
			iterator,
		),
	})
	if err != nil {
		return nil, err
	}

	iterator.blockBatchIterator = blockIterator

	return iterator, nil
}

// Iter iterates the given chain between the given start and end heights,
// and calls the callback when a proposal event is iterated.
func (i *ProposalIterator) Iter() error {
	i.sawNonCanonical = false
	return i.blockBatchIterator.Iter()
}

// SawNonCanonicalEvent reports whether the most recent Iter call observed a
// non-canonical Proposed event. When true, the caller MUST NOT advance its L1
// scan cursor past the iterated range: the RPC's log index is out of sync
// with its head for that range, and the same query may be silently dropping
// canonical logs at the same height. The caller should re-run the same range
// on a later sync cycle, after the RPC has converged.
func (i *ProposalIterator) SawNonCanonicalEvent() bool {
	return i.sawNonCanonical
}

// end ends the current iteration.
func (i *ProposalIterator) end() {
	i.isEnd = true
}

// assembleProposalIteratorCallback assembles the callback which will be used
// by a event iterator's inner block iterator.
func assembleProposalIteratorCallback(
	rpcClient *rpc.Client,
	callback OnProposalEvent,
	eventIter *ProposalIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		var (
			endHeight      = end.Number.Uint64()
			lastProposalID uint64
		)

		iter, err := rpcClient.ShastaClients.Inbox.FilterProposed(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx}, nil, nil,
		)
		if err != nil {
			return err
		}
		defer iter.Close()

		for iter.Next() {
			event := iter.Event

			// Verify the event is from the canonical L1 chain. After an L1 reorg, the
			// RPC's eth_getLogs may briefly return logs from orphaned blocks before its
			// log index converges with its new head; HeaderByHash is not a canonicality
			// check because a node may still serve an orphaned block by hash.
			canonicalHeader, err := rpcClient.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
			if err != nil {
				return fmt.Errorf("failed to fetch canonical L1 header at %d: %w", event.Raw.BlockNumber, err)
			}
			if isNonCanonicalLog(event.Raw, canonicalHeader) {
				log.Warn(
					"Skipping non-canonical Proposed event; will not advance L1Current for this range",
					"proposalID", event.Id,
					"l1Height", event.Raw.BlockNumber,
					"eventBlockHash", event.Raw.BlockHash,
					"canonicalBlockHash", canonicalHeader.Hash(),
					"removed", event.Raw.Removed,
				)
				eventIter.sawNonCanonical = true
				continue
			}

			proposedEventPayload := metadata.NewTaikoProposalMetadataShasta(event, canonicalHeader.Time)
			proposalID := proposedEventPayload.Shasta().GetEventData().Id.Uint64()
			log.Debug("Processing Proposed event", "proposalID", proposalID, "l1BlockHeight", event.Raw.BlockNumber)

			if lastProposalID != 0 && proposalID != lastProposalID+1 {
				log.Warn(
					"Proposed event is not continuous, rescan the L1 chain",
					"fromL1Block", start.Number,
					"toL1Block", endHeight,
					"lastScannedProposalID", lastProposalID,
					"currentScannedProposalID", proposalID,
				)
				return fmt.Errorf(
					"proposed event is not continuous, lastScannedProposalID: %d, currentScannedProposalID: %d",
					lastProposalID, proposalID,
				)
			}

			if err := callback(ctx, proposedEventPayload, eventIter.end); err != nil {
				log.Warn("Error while processing Proposed events, keep retrying", "error", err)
				return err
			}

			if eventIter.isEnd {
				log.Debug("ProposedIterator is ended", "start", start.Number, "end", endHeight)
				endFunc()
				return nil
			}

			log.Debug("Updating current block cursor for processing Proposed events", "block", canonicalHeader.Number)

			lastProposalID = proposalID

			updateCurrentFunc(canonicalHeader)
		}

		// Check if there is any error during the iteration.
		if iter.Error() != nil {
			return iter.Error()
		}

		return nil
	}
}
