package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"golang.org/x/sync/errgroup"

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

// RealTime is responsible for inserting RealTime blocks to the L2 execution engine.
type RealTime struct {
	rpc                  *rpc.Client
	progressTracker      *beaconsync.SyncProgressTracker
	latestSeenProposalCh chan *encoding.LastSeenProposal
	anchorConstructor    *anchorTxConstructor.AnchorTxConstructor
	mutex                sync.Mutex
}

// NewBlocksInserterRealTime creates a new RealTime instance.
func NewBlocksInserterRealTime(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) *RealTime {
	return &RealTime{
		rpc:                  rpc,
		progressTracker:      progressTracker,
		anchorConstructor:    anchorConstructor,
		latestSeenProposalCh: latestSeenProposalCh,
	}
}

// InsertBlocks inserts new RealTime blocks to the L2 execution engine.
func (i *RealTime) InsertBlocks(
	_ context.Context,
	_ metadata.TaikoProposalMetaData,
	_ eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	return errors.New("not supported in RealTime block inserter")
}

// InsertBlocksWithManifest inserts new RealTime blocks to the L2 execution engine based on the given derivation
// source payload.
func (i *RealTime) InsertBlocksWithManifest(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (*big.Int, error) {
	if !metadata.IsRealTime() {
		return nil, errors.New("metadata is not for RealTime fork blocks")
	}

	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
		// to the channel.
		latestSeenProposal = &encoding.LastSeenProposal{TaikoProposalMetaData: metadata}
		meta               = metadata.RealTime()
	)

	log.Debug(
		"Inserting RealTime blocks to L2 execution engine",
		"proposalHash", common.BytesToHash(meta.GetEventData().ProposalHash[:]),
		"invalidManifest", sourcePayload.Default,
	)

	var (
		parent          = sourcePayload.ParentBlock.Header()
		lastPayloadData *engine.ExecutableData
	)

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
			proposalHash := meta.GetEventData().ProposalHash
			log.Debug(
				"Checking if batch is in canonical chain",
				"proposalHash", common.BytesToHash(proposalHash[:]),
				"timestamp", meta.GetTimestamp(),
				"derivationSources", len(meta.GetEventData().Sources),
				"parentNumber", parent.Number,
				"parentHash", parent.Hash(),
			)

			lastBlockHeader, isKnown, err := isKnownCanonicalBatchRealTime(
				ctx,
				i.rpc,
				i.anchorConstructor,
				metadata,
				sourcePayload,
				parent,
			)
			if err != nil {
				return nil, fmt.Errorf("failed to check if RealTime batch is known in canonical chain: %w", err)
			}
			if isKnown && lastBlockHeader != nil {
				log.Info(
					"Known RealTime batch in canonical chain",
					"proposalHash", common.BytesToHash(proposalHash[:]),
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
				if err := updateL1OriginForBatchRealTime(ctx, i.rpc, parent, metadata, sourcePayload); err != nil {
					return nil, fmt.Errorf(
						"failed to update L1 origin for RealTime batch (proposalHash %s): %w",
						common.BytesToHash(proposalHash[:]),
						err,
					)
				}

				return lastBlockHeader.Number, nil
			}
		}

		// Assemble execution payload metadata and anchor transaction for this block.
		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaRealTime(
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
			"New RealTime L2 block inserted",
			"blockID", lastPayloadData.Number,
			"hash", lastPayloadData.BlockHash,
			"coinbase", lastPayloadData.FeeRecipient.Hex(),
			"transactions", len(lastPayloadData.Transactions),
			"transactionsInManifest", sourcePayload.BlockPayloads[j].Transactions.Len(),
			"timestamp", lastPayloadData.Timestamp,
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"proposalHash", common.BytesToHash(meta.GetEventData().ProposalHash[:]),
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

// assembleCreateExecutionPayloadMetaRealTime assembles the metadata for creating an execution payload,
// and the anchor transaction for the given RealTime block.
func assembleCreateExecutionPayloadMetaRealTime(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	parent *types.Header,
	blockIndex int,
) (*createExecutionPayloadsMetaData, *types.Transaction, error) {
	if !metadata.IsRealTime() {
		return nil, nil, fmt.Errorf("metadata is not for RealTime fork")
	}
	if blockIndex >= len(sourcePayload.BlockPayloads) {
		return nil, nil, fmt.Errorf("block index %d out of bounds (%d)", blockIndex, len(sourcePayload.BlockPayloads))
	}

	var (
		meta              = metadata.RealTime()
		blockID           = new(big.Int).Add(parent.Number, common.Big1)
		blockInfo         = sourcePayload.BlockPayloads[blockIndex]
		maxAnchorBlockNum = meta.GetMaxAnchorBlockNumber()
		anchorBlockID     = new(big.Int).SetUint64(maxAnchorBlockNum)
	)

	difficulty, err := encoding.CalculateShastaDifficulty(parent.Difficulty, blockID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate difficulty: %w", err)
	}

	baseFee, err := rpc.CalculateBaseFeeShasta(ctx, parent)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate base fee: %w", err)
	}

	log.Info("L2 baseFee", "blockID", blockID, "basefee", utils.WeiToGWei(baseFee))

	// Fetch the anchor block header from L1 using maxAnchorBlockNumber.
	anchorBlockHeader, err := rpc.L1.HeaderByNumber(ctx, anchorBlockID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to fetch anchor block: %w", err)
	}
	var (
		anchorBlockHeaderHash = anchorBlockHeader.Hash()
		anchorBlockHeaderRoot = anchorBlockHeader.Root
	)

	log.Info(
		"L2 anchor block",
		"number", anchorBlockID,
		"hash", anchorBlockHeaderHash,
		"root", anchorBlockHeaderRoot,
	)

	// For the first block, use the signal slots from the event; for subsequent blocks, use empty signal slots.
	var signalSlots [][32]byte
	if blockIndex == 0 {
		signalSlots = meta.GetSignalSlots()
	}

	anchorTx, err := anchorConstructor.AssembleAnchorV4WithSignalSlotsTx(
		ctx,
		parent,
		anchorBlockID,
		anchorBlockHeaderHash,
		anchorBlockHeaderRoot,
		signalSlots,
		blockID,
		baseFee,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create anchor transaction: %w", err)
	}

	proposalHash := meta.GetEventData().ProposalHash

	// RealTime blocks use zero proposal ID in extraData.
	extraData, err := encodeShastaExtraData(meta.GetEventData().BasefeeSharingPctg, new(big.Int))
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode extraData: %w", err)
	}

	// Set batchID only for the last block in the proposal.
	var batchID *big.Int
	if len(sourcePayload.BlockPayloads)-1 == blockIndex {
		batchID = new(big.Int).SetBytes(proposalHash[:])
	}

	return &createExecutionPayloadsMetaData{
		BlockID:               blockID,
		BatchID:               batchID,
		ExtraData:             extraData,
		SuggestedFeeRecipient: blockInfo.Coinbase,
		GasLimit:              blockInfo.GasLimit,
		Difficulty:            common.BytesToHash(difficulty),
		Timestamp:             blockInfo.Timestamp,
		ParentHash:            parent.Hash(),
		L1Origin: &rawdb.L1Origin{
			BlockID:       blockID,
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: metadata.GetRawBlockHeight(),
			L1BlockHash:   metadata.GetRawBlockHash(),
		},
		Txs:         blockInfo.Transactions,
		Withdrawals: make([]*types.Withdrawal, 0),
		BaseFee:     baseFee,
	}, anchorTx, nil
}

// isKnownCanonicalBatchRealTime checks if all blocks in the given RealTime batch are in the canonical chain already,
// and returns the header of the last block in the batch if it is.
func isKnownCanonicalBatchRealTime(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	parent *types.Header,
) (*types.Header, bool, error) {
	if !metadata.IsRealTime() {
		return nil, false, fmt.Errorf("metadata is not for RealTime fork blocks")
	}
	var (
		headers = make([]*types.Header, len(sourcePayload.BlockPayloads))
		g       = new(errgroup.Group)
	)

	// Check each block in the batch, and if all blocks are known in canonical, return the header of the last block.
	for idx := 0; idx < len(sourcePayload.BlockPayloads); idx++ {
		g.Go(func() error {
			parentHeader, err := rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(parent.Number.Uint64()+uint64(idx)))
			if err != nil {
				if errors.Is(err, ethereum.NotFound) {
					return errBatchNotKnown
				}
				return fmt.Errorf("failed to get parent block by number %d: %w", parent.Number.Uint64()+uint64(idx), err)
			}

			createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaRealTime(
				ctx,
				rpc,
				anchorConstructor,
				metadata,
				sourcePayload,
				parentHeader,
				idx,
			)
			if err != nil {
				return fmt.Errorf("failed to assemble RealTime execution payload creation metadata: %w", err)
			}

			b, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, createExecutionPayloadsMetaData.Txs...))
			if err != nil {
				return fmt.Errorf("failed to RLP encode tx list: %w", err)
			}

			var known bool
			if headers[idx], known, err = isKnownCanonicalBlock(
				ctx,
				rpc,
				&createPayloadAndSetHeadMetaData{
					createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
					Parent:                          parentHeader,
				},
				b,
				anchorTx,
			); err != nil {
				return err
			}
			if !known {
				return errBatchNotKnown
			}
			return nil
		})
	}

	// Wait for all goroutines to finish, and check for errors.
	if err := g.Wait(); err != nil {
		if errors.Is(err, errBatchNotKnown) {
			return nil, false, nil
		}
		return nil, false, err
	}

	return headers[len(headers)-1], true, nil
}

// updateL1OriginForBatchRealTime updates the L1 origin for the given batch of RealTime blocks.
func updateL1OriginForBatchRealTime(
	ctx context.Context,
	rpc *rpc.Client,
	parentHeader *types.Header,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
) error {
	if !metadata.IsRealTime() {
		return fmt.Errorf("metadata is not for RealTime fork blocks")
	}

	meta := metadata.RealTime()
	lastBlockID := parentHeader.Number.Uint64() + uint64(len(sourcePayload.BlockPayloads))
	proposalHash := meta.GetEventData().ProposalHash

	return updateL1OriginForBlocks(
		ctx,
		rpc,
		len(sourcePayload.BlockPayloads),
		func(i int) *big.Int {
			return new(big.Int).SetUint64(lastBlockID - uint64(len(sourcePayload.BlockPayloads)-1-i))
		},
		func() *big.Int { return new(big.Int).SetBytes(proposalHash[:]) },
		meta.GetRawBlockHeight(),
		meta.GetRawBlockHash(),
	)
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *RealTime) InsertPreconfBlocksFromEnvelopes(
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
			"New preconfirmation L2 block inserted",
			"blockID", header.Number,
			"hash", header.Hash(),
			"fork", "RealTime",
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
func (i *RealTime) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		proposalHash := proposal.TaikoProposalMetaData.RealTime().GetEventData().ProposalHash
		log.Debug(
			"Sending latest seen realtime proposal from blocksInserter",
			"proposalHash", common.BytesToHash(proposalHash[:]),
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}

// insertPreconfBlockFromEnvelope the inner method to insert a preconfirmation block from
// the given envelope.
func (i *RealTime) insertPreconfBlockFromEnvelope(
	ctx context.Context,
	envelope *preconf.Envelope,
) (*types.Header, error) {
	return InsertPreconfBlockFromEnvelope(ctx, i.rpc, envelope)
}
