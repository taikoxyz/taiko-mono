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
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/holiman/uint256"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlocksInserterPacaya is responsible for inserting Pacaya blocks to the L2 execution engine.
type BlocksInserterPacaya struct {
	rpc                  *rpc.Client
	progressTracker      *beaconsync.SyncProgressTracker
	blobDatasource       *rpc.BlobDataSource
	txListDecompressor   *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	anchorConstructor    *anchorTxConstructor.AnchorTxConstructor // TaikoAnchor.anchorV3 transactions constructor
	calldataFetcher      txlistFetcher.TxListFetcher
	blobFetcher          txlistFetcher.TxListFetcher
	latestSeenProposalCh chan *encoding.LastSeenProposal
	mutex                sync.Mutex
}

// NewBlocksInserterPacaya creates a new BlocksInserterPacaya instance.
func NewBlocksInserterPacaya(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	txListDecompressor *txListDecompressor.TxListDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	calldataFetcher txlistFetcher.TxListFetcher,
	blobFetcher txlistFetcher.TxListFetcher,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) *BlocksInserterPacaya {
	return &BlocksInserterPacaya{
		rpc:                  rpc,
		progressTracker:      progressTracker,
		blobDatasource:       blobDatasource,
		txListDecompressor:   txListDecompressor,
		anchorConstructor:    anchorConstructor,
		calldataFetcher:      calldataFetcher,
		blobFetcher:          blobFetcher,
		latestSeenProposalCh: latestSeenProposalCh,
	}
}

// FetchTxListBytes fetches the txList bytes from blob sidecars or calldata.
func (i *BlocksInserterPacaya) FetchTxListBytes(
	ctx context.Context,
	meta metadata.TaikoBatchMetaDataPacaya,
) ([]byte, error) {
	if len(meta.GetBlobHashes()) != 0 {
		txListBytes, err := i.blobFetcher.FetchPacaya(ctx, meta)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch tx list from blob: %w", err)
		}
		return txListBytes, nil
	}

	txListBytes, err := i.calldataFetcher.FetchPacaya(ctx, meta)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch tx list from calldata: %w", err)
	}
	return txListBytes, nil
}

// InsertBlocks inserts new Pacaya blocks to the L2 execution engine.
func (i *BlocksInserterPacaya) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	if !metadata.IsPacaya() {
		return fmt.Errorf("metadata is not for Pacaya fork")
	}
	txListBytes, err := i.FetchTxListBytes(ctx, metadata.Pacaya())
	if err != nil {
		return err
	}

	return i.InsertBlocksWithTxListBytes(ctx, metadata, txListBytes)
}

// InsertBlocksWithTxListBytes inserts new Pacaya blocks using the provided txList bytes.
func (i *BlocksInserterPacaya) InsertBlocksWithTxListBytes(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	txListBytes []byte,
) (err error) {
	meta := metadata.Pacaya()
	// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
	// to the channel.
	latestSeenProposal := &encoding.LastSeenProposal{TaikoProposalMetaData: metadata}
	allTxs := i.txListDecompressor.TryDecompress(txListBytes, len(meta.GetBlobHashes()) != 0)

	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		parent          *types.Header
		lastPayloadData *engine.ExecutableData
	)

	log.Debug(
		"Inserting blocks to L2 execution engine",
		"batchID", meta.GetBatchID(),
		"lastBlockID", meta.GetLastBlockID(),
		"assignedProver", meta.GetProposer(),
		"lastTimestamp", meta.GetLastBlockTimestamp(),
		"coinbase", meta.GetCoinbase(),
		"numBlobs", len(meta.GetBlobHashes()),
		"blocks", len(meta.GetBlocks()),
	)

	go i.sendLatestSeenProposal(latestSeenProposal)

	for j := range meta.GetBlocks() {
		// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
		// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
		if i.progressTracker.Triggered() {
			// Already synced through beacon sync, just skip this event.
			if new(big.Int).SetUint64(meta.GetLastBlockID()).Cmp(i.progressTracker.LastSyncedBlockID()) <= 0 {
				return nil
			}

			parent, err = i.rpc.L2.HeaderByHash(ctx, i.progressTracker.LastSyncedBlockHash())
		} else {
			var parentNumber *big.Int
			if lastPayloadData == nil {
				if meta.GetBatchID().Uint64() == i.rpc.PacayaClients.ForkHeights.Pacaya {
					parentNumber = new(big.Int).SetUint64(meta.GetBatchID().Uint64() - 1)
				} else {
					lastBatch, err := i.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(meta.GetBatchID().Uint64()-1))
					if err != nil {
						return fmt.Errorf("failed to fetch last batch (%d): %w", meta.GetBatchID().Uint64()-1, err)
					}
					parentNumber = new(big.Int).SetUint64(lastBatch.LastBlockId)
				}
			} else {
				parentNumber = new(big.Int).SetUint64(lastPayloadData.Number)
			}

			parent, err = i.rpc.L2ParentByCurrentBlockID(ctx, new(big.Int).Add(parentNumber, common.Big1))
		}
		if err != nil {
			return fmt.Errorf("failed to fetch L2 parent block: %w", err)
		}

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
				"batchID", meta.GetBatchID(),
				"lastBlockID", meta.GetLastBlockID(),
				"assignedProver", meta.GetProposer(),
				"lastTimestamp", meta.GetLastBlockTimestamp(),
				"coinbase", meta.GetCoinbase(),
				"numBlobs", len(meta.GetBlobHashes()),
				"blocks", len(meta.GetBlocks()),
				"parentNumber", parent.Number,
				"parentHash", parent.Hash(),
			)

			lastBlockHeader, err := isKnownCanonicalBatch(
				ctx,
				i.rpc,
				i.anchorConstructor,
				metadata,
				allTxs,
				txListBytes,
				parent,
			)
			if err != nil {
				log.Info("Unknown batch for the current canonical chain", "batchID", meta.GetBatchID(), "reason", err)
			} else if lastBlockHeader != nil {
				log.Info(
					"🧬 Known batch in canonical chain",
					"batchID", meta.GetBatchID(),
					"lastBlockID", meta.GetLastBlockID(),
					"lastBlockHash", lastBlockHeader.Hash(),
					"assignedProver", meta.GetProposer(),
					"lastTimestamp", meta.GetLastBlockTimestamp(),
					"coinbase", meta.GetCoinbase(),
					"numBlobs", len(meta.GetBlobHashes()),
					"blocks", len(meta.GetBlocks()),
					"parentNumber", parent.Number,
					"parentHash", parent.Hash(),
				)

				// Update the L1 origin for each block in the batch.
				if err := updateL1OriginForBatch(ctx, i.rpc, metadata); err != nil {
					return fmt.Errorf("failed to update L1 origin for batch (%d): %w", meta.GetBatchID().Uint64(), err)
				}

				return nil
			}
		}

		// Otherwise, we need to create a new execution payload and set it as the head block in L2 EE.
		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaPacaya(
			ctx,
			i.rpc,
			i.anchorConstructor,
			metadata,
			allTxs,
			parent,
			j,
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
				AnchorBlockID:                   new(big.Int).SetUint64(meta.GetAnchorBlockID()),
				AnchorBlockHash:                 meta.GetAnchorBlockHash(),
				BaseFeeConfig:                   meta.GetBaseFeeConfig(),
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
			"🔗 New L2 block inserted",
			"blockID", lastPayloadData.Number,
			"hash", lastPayloadData.BlockHash,
			"coinbase", lastPayloadData.FeeRecipient.Hex(),
			"transactions", len(lastPayloadData.Transactions),
			"timestamp", lastPayloadData.Timestamp,
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"batchID", meta.GetBatchID(),
			"gasLimit", lastPayloadData.GasLimit,
			"gasUsed", lastPayloadData.GasUsed,
			"parentHash", lastPayloadData.ParentHash,
			"indexInBatch", j,
		)

		metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
	}

	// Mark the last seen proposal as not preconfirmed and send it to the channel.
	latestSeenProposal.PreconfChainReorged = true
	go i.sendLatestSeenProposal(latestSeenProposal)

	return nil
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *BlocksInserterPacaya) InsertPreconfBlocksFromEnvelopes(
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

// insertPreconfBlockFromEnvelope the inner method to insert a preconfirmation block from
// the given envelope.
func (i *BlocksInserterPacaya) insertPreconfBlockFromEnvelope(
	ctx context.Context,
	envelope *preconf.Envelope,
) (*types.Header, error) {
	var signature [65]byte
	if envelope.Signature != nil {
		signature = *envelope.Signature
	}

	log.Debug(
		"Inserting preconfirmation block from execution payload envelope",
		"blockID", uint64(envelope.Payload.BlockNumber),
		"blockHash", envelope.Payload.BlockHash,
		"parentHash", envelope.Payload.ParentHash,
		"timestamp", envelope.Payload.Timestamp,
		"feeRecipient", envelope.Payload.FeeRecipient,
		"signature", common.Bytes2Hex(signature[:]),
	)

	// Ensure the preconfirmation block number is greater than the current head L1 origin block ID.
	headL1Origin, err := i.rpc.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return nil, fmt.Errorf("failed to fetch head L1 origin: %w", err)
	}

	// When the chain only has the genesis block, we shall skip this check.
	if headL1Origin != nil {
		if uint64(envelope.Payload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
			return nil, fmt.Errorf(
				"preconfirmation block ID (%d, %s) is less than or equal to the current head L1 origin block ID (%d)",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				headL1Origin.BlockID,
			)
		}

		ok, err := i.IsBasedOnCanonicalChain(ctx, envelope, headL1Origin)
		if err != nil {
			return nil, fmt.Errorf(
				"failed to check if preconfirmation block (%d, %s) is in canonical chain: %w",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				err,
			)
		}
		if !ok {
			return nil, fmt.Errorf(
				"preconfirmation block (%d, %s) is not in the canonical chain, head L1 origin: (%d, %s)",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				headL1Origin.BlockID,
				headL1Origin.L2BlockHash,
			)
		}
	}

	if len(envelope.Payload.Transactions) == 0 {
		return nil, fmt.Errorf("no transactions data in the payload")
	}

	// Decompress the transactions list.
	decompressedTxs, err := utils.Decompress(envelope.Payload.Transactions[0])
	if err != nil {
		return nil, fmt.Errorf("failed to decompress transactions list bytes: %w", err)
	}
	var (
		txListHash = crypto.Keccak256Hash(decompressedTxs)
		args       = &miner.BuildPayloadArgs{
			Parent:       envelope.Payload.ParentHash,
			Timestamp:    uint64(envelope.Payload.Timestamp),
			FeeRecipient: envelope.Payload.FeeRecipient,
			Random:       common.Hash(envelope.Payload.PrevRandao),
			Withdrawals:  make([]*types.Withdrawal, 0),
			Version:      engine.PayloadV2,
			TxListHash:   &txListHash,
		}
	)

	payloadID := args.Id()

	var u256BaseFee = uint256.Int(envelope.Payload.BaseFeePerGas)

	log.Debug(
		"Payload arguments",
		"blockID", uint64(envelope.Payload.BlockNumber),
		"parent", args.Parent.Hex(),
		"timestamp", args.Timestamp,
		"feeRecipient", args.FeeRecipient.Hex(),
		"random", args.Random.Hex(),
		"txListHash", args.TxListHash.Hex(),
		"id", payloadID.String(),
		"signature", common.Bytes2Hex(signature[:]),
	)

	payload, err := createExecutionPayloadsAndSetHead(
		ctx,
		i.rpc,
		&createExecutionPayloadsMetaData{
			BlockID:               new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber)),
			ExtraData:             envelope.Payload.ExtraData,
			SuggestedFeeRecipient: envelope.Payload.FeeRecipient,
			GasLimit:              uint64(envelope.Payload.GasLimit),
			Difficulty:            common.Hash(envelope.Payload.PrevRandao),
			Timestamp:             uint64(envelope.Payload.Timestamp),
			ParentHash:            envelope.Payload.ParentHash,
			L1Origin: &rawdb.L1Origin{
				BlockID:            new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber)),
				L2BlockHash:        common.Hash{}, // Will be set by taiko-geth.
				L1BlockHeight:      nil,
				L1BlockHash:        common.Hash{},
				Signature:          signature,
				IsForcedInclusion:  envelope.IsForcedInclusion,
				BuildPayloadArgsID: payloadID,
			},
			BaseFee:     u256BaseFee.ToBig(),
			Withdrawals: make([]*types.Withdrawal, 0),
		},
		decompressedTxs,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution data: %w", err)
	}

	metrics.DriverL2PreconfHeadHeightGauge.Set(float64(envelope.Payload.BlockNumber))

	return i.rpc.L2.HeaderByHash(ctx, payload.BlockHash)
}

// IsBasedOnCanonicalChain checks if the given executable data is based on the canonical chain.
func (i *BlocksInserterPacaya) IsBasedOnCanonicalChain(
	ctx context.Context,
	envelope *preconf.Envelope,
	headL1Origin *rawdb.L1Origin,
) (bool, error) {
	canonicalParent, err := i.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber-1)))
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return false, fmt.Errorf("failed to fetch canonical parent block: %w", err)
	}
	// If the parent hash of the executable data matches the canonical parent block hash, it is in the canonical chain.
	if canonicalParent != nil && canonicalParent.Hash() == envelope.Payload.ParentHash {
		return true, nil
	}

	// Otherwise, we try to connect the L2 ancient blocks to the L2 block in current L1 head Origin.
	currentParent, err := i.rpc.L2.HeaderByHash(ctx, envelope.Payload.ParentHash)
	if err != nil {
		return false, fmt.Errorf("failed to fetch current parent block (%s): %w", envelope.Payload.ParentHash, err)
	}
	for currentParent.Number.Cmp(headL1Origin.BlockID) > 0 {
		if currentParent, err = i.rpc.L2.HeaderByHash(ctx, currentParent.ParentHash); err != nil {
			return false, fmt.Errorf("failed to fetch current parent block (%s): %w", currentParent.ParentHash, err)
		}
	}

	// If the current parent block hash matches the L2 block hash in the head L1 origin, it is in the canonical chain.
	isBasedOnCanonicalChain := currentParent.Hash() == headL1Origin.L2BlockHash

	log.Debug(
		"Check if block is based on canonical chain",
		"blockID", uint64(envelope.Payload.BlockNumber),
		"blockHash", envelope.Payload.BlockHash,
		"parentHash", envelope.Payload.ParentHash,
		"headL1OriginBlockID", headL1Origin.BlockID,
		"isBasedOnCanonicalChain", isBasedOnCanonicalChain,
	)

	return isBasedOnCanonicalChain, nil
}

// sendLatestSeenProposal sends the latest seen proposal to the channel, if it is not nil.
func (i *BlocksInserterPacaya) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		log.Debug(
			"Sending latest seen proposal from blocksInserter",
			"batchID", proposal.TaikoProposalMetaData.Pacaya().GetBatchID(),
			"lastBlockID", proposal.TaikoProposalMetaData.Pacaya().GetLastBlockID(),
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}
