package event

import (
	"context"
	"fmt"
	"math/big"
	"net/url"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	blocksInserter "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/blocks_inserter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"

	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

const (
	reorgCheckRewindBlocks = 10 // Number of blocks to rewind when checking reorg by comparing the verified block hash
)

// Syncer responsible for letting the L2 execution engine catching up with protocol's latest
// pending block through deriving L1 calldata.
type Syncer struct {
	ctx                context.Context
	rpc                *rpc.Client
	state              *state.State
	progressTracker    *beaconsync.SyncProgressTracker        // Sync progress tracker
	txListDecompressor *txListDecompressor.TxListDecompressor // Transactions list decompressor

	// Blocks inserters
	blocksInserterOntake blocksInserter.Inserter // Ontake blocks inserter
	blocksInserterPacaya blocksInserter.Inserter // Pacaya blocks inserter

	lastInsertedBlockID *big.Int
	reorgDetectedFlag   bool
}

// NewSyncer creates a new syncer instance.
func NewSyncer(
	ctx context.Context,
	client *rpc.Client,
	state *state.State,
	progressTracker *beaconsync.SyncProgressTracker,
	blobServerEndpoint *url.URL,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) (*Syncer, error) {
	constructor, err := anchorTxConstructor.New(client)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize anchor constructor: %w", err)
	}

	protocolConfigs, err := client.GetProtocolConfigs(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, err
	}
	blobDataSource := rpc.NewBlobDataSource(
		ctx,
		client,
		blobServerEndpoint,
	)

	txListDecompressor := txListDecompressor.NewTxListDecompressor(
		uint64(protocolConfigs.BlockMaxGasLimit()),
		rpc.BlockMaxTxListBytes,
		client.L2.ChainID,
	)

	var (
		txListFetcherBlob     = txlistFetcher.NewBlobTxListFetcher(client, blobDataSource)
		txListFetcherCalldata = txlistFetcher.NewCalldataFetch(client)
	)
	return &Syncer{
		ctx:                ctx,
		rpc:                client,
		state:              state,
		progressTracker:    progressTracker,
		txListDecompressor: txListDecompressor,
		blocksInserterOntake: blocksInserter.NewBlocksInserterOntake(
			client,
			progressTracker,
			blobDataSource,
			txListDecompressor,
			constructor,
			txListFetcherCalldata,
			txListFetcherBlob,
		),
		blocksInserterPacaya: blocksInserter.NewBlocksInserterPacaya(
			client,
			progressTracker,
			blobDataSource,
			txListDecompressor,
			constructor,
			txListFetcherCalldata,
			txListFetcherBlob,
			latestSeenProposalCh,
		),
	}, nil
}

// ProcessL1Blocks fetches all `TaikoL1.BlockProposed` events between given
// L1 block heights, and then tries inserting them into L2 execution engine's blockchain.
func (s *Syncer) ProcessL1Blocks(ctx context.Context) error {
	for {
		if err := s.processL1Blocks(ctx); err != nil {
			return err
		}

		// If the L1 chain has been reorged, we process the new L1 blocks again with
		// the new L1Current cursor.
		if s.reorgDetectedFlag {
			s.reorgDetectedFlag = false
			continue
		}

		return nil
	}
}

// processL1Blocks is the inner method which responsible for processing
// all new L1 blocks.
func (s *Syncer) processL1Blocks(ctx context.Context) error {
	var (
		l1End          = s.state.GetL1Head()
		startL1Current = s.state.GetL1Current()
	)
	// If there is a L1 reorg, sometimes this will happen.
	if startL1Current.Number.Uint64() >= l1End.Number.Uint64() && startL1Current.Hash() != l1End.Hash() {
		newL1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).Sub(l1End.Number, common.Big1))
		if err != nil {
			return err
		}

		log.Info(
			"Reorg detected",
			"oldL1CurrentHeight", startL1Current.Number,
			"oldL1CurrentHash", startL1Current.Hash(),
			"newL1CurrentHeight", newL1Current.Number,
			"newL1CurrentHash", newL1Current.Hash(),
			"l1Head", l1End.Number,
		)

		s.state.SetL1Current(newL1Current)
		s.lastInsertedBlockID = nil
	}

	iter, err := eventIterator.NewBlockProposedIterator(ctx, &eventIterator.BlockProposedIteratorConfig{
		Client:               s.rpc.L1,
		TaikoL1:              s.rpc.OntakeClients.TaikoL1,
		TaikoInbox:           s.rpc.PacayaClients.TaikoInbox,
		PacayaForkHeight:     s.rpc.PacayaClients.ForkHeight,
		StartHeight:          s.state.GetL1Current().Number,
		EndHeight:            l1End.Number,
		OnBlockProposedEvent: s.onBlockProposed,
	})
	if err != nil {
		return err
	}

	if err := iter.Iter(); err != nil {
		return err
	}

	// If there is a L1 reorg, we don't update the L1Current cursor.
	if !s.reorgDetectedFlag {
		s.state.SetL1Current(l1End)
		metrics.DriverL1CurrentHeightGauge.Set(float64(s.state.GetL1Current().Number.Uint64()))
	}

	return nil
}

// OnBlockProposed is a `BlockProposed` event callback which responsible for
// inserting the proposed block one by one to the L2 execution engine.
func (s *Syncer) onBlockProposed(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	var (
		firstBlockID *big.Int
		lastBlockID  *big.Int
		timestamp    uint64
	)
	if meta.IsPacaya() {
		firstBlockID = new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID() - uint64(len(meta.Pacaya().GetBlocks())) + 1)
		lastBlockID = new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID())
		timestamp = meta.Pacaya().GetLastBlockTimestamp()
	} else {
		firstBlockID = meta.Ontake().GetBlockID()
		lastBlockID = meta.Ontake().GetBlockID()
		timestamp = meta.Ontake().GetTimestamp()
	}

	// We simply ignore the genesis block's `BlockProposedV2` / `BatchesProposed` event.
	if lastBlockID.Cmp(common.Big0) == 0 {
		return nil
	}

	// If we are not inserting a block whose parent block is the latest verified block in protocol,
	// and the node hasn't just finished the P2P sync, we check if the L1 chain has been reorged.
	if !s.progressTracker.Triggered() {
		reorgCheckResult, err := s.checkReorg(ctx, firstBlockID)
		if err != nil {
			return err
		}

		if reorgCheckResult.IsReorged {
			log.Info(
				"Reset L1Current cursor due to L1 reorg",
				"l1CurrentHeightOld", s.state.GetL1Current().Number,
				"l1CurrentHashOld", s.state.GetL1Current().Hash(),
				"l1CurrentHeightNew", reorgCheckResult.L1CurrentToReset.Number,
				"l1CurrentHashNew", reorgCheckResult.L1CurrentToReset.Hash(),
				"lastInsertedBlockIDOld", s.lastInsertedBlockID,
				"lastInsertedBlockIDNew", reorgCheckResult.LastHandledBlockIDToReset,
			)
			s.state.SetL1Current(reorgCheckResult.L1CurrentToReset)
			s.lastInsertedBlockID = reorgCheckResult.LastHandledBlockIDToReset
			s.reorgDetectedFlag = true
			endIter()

			return nil
		}
	}

	// Ignore those already inserted blocks.
	if s.lastInsertedBlockID != nil && lastBlockID.Cmp(s.lastInsertedBlockID) <= 0 {
		log.Debug(
			"Skip already inserted block",
			"blockID", lastBlockID,
			"lastInsertedBlockID", s.lastInsertedBlockID,
		)
		return nil
	}

	// If the event's timestamp is in the future, we wait until the timestamp is reached, should
	// only happen when testing.
	if timestamp > uint64(time.Now().Unix()) {
		log.Warn(
			"Future L2 block, waiting",
			"L2BlockTimestamp", timestamp,
			"now", time.Now().Unix(),
		)
		time.Sleep(time.Until(time.Unix(int64(timestamp), 0)))
	}

	// Insert new blocks to L2 EE's chain.
	if meta.IsPacaya() {
		log.Info(
			"New BatchProposed event",
			"l1Height", meta.GetRawBlockHeight(),
			"l1Hash", meta.GetRawBlockHash(),
			"batchID", meta.Pacaya().GetBatchID(),
			"lastBlockID", lastBlockID,
			"lastTimestamp", meta.Pacaya().GetLastBlockTimestamp(),
			"blocks", len(meta.Pacaya().GetBlocks()),
		)
		if err := s.blocksInserterPacaya.InsertBlocks(ctx, meta, endIter); err != nil {
			return err
		}
	} else {
		log.Info(
			"New BlockProposedV2 event",
			"l1Height", meta.GetRawBlockHeight(),
			"l1Hash", meta.GetRawBlockHash(),
			"blockID", meta.Ontake().GetBlockID(),
			"coinbase", meta.Ontake().GetCoinbase(),
		)
		if err := s.blocksInserterOntake.InsertBlocks(ctx, meta, endIter); err != nil {
			return err
		}
	}

	metrics.DriverL1CurrentHeightGauge.Set(float64(meta.GetRawBlockHeight().Uint64()))
	s.lastInsertedBlockID = lastBlockID

	if s.progressTracker.Triggered() {
		s.progressTracker.ClearMeta()
	}

	return nil
}

// checkLastVerifiedBlockMismatch checks if there is a mismatch between protocol's last verified block hash and
// the corresponding L2 EE block hash.
func (s *Syncer) checkLastVerifiedBlockMismatch(ctx context.Context) (*rpc.ReorgCheckResult, error) {
	var (
		reorgCheckResult      = new(rpc.ReorgCheckResult)
		lastVerifiedBatchID   uint64
		lastVerifiedBlockID   uint64
		lastVerifiedBlockHash common.Hash
		err                   error
	)

	// Fetch the latest verified block hash.
	ts, err := s.rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		blockInfo, err := s.rpc.GetLastVerifiedBlockOntake(ctx)
		if err != nil {
			return nil, err
		}

		lastVerifiedBlockID = blockInfo.BlockId
		lastVerifiedBlockHash = blockInfo.BlockHash
	} else {
		lastVerifiedBatchID = ts.BatchId
		lastVerifiedBlockID = ts.BlockId
		lastVerifiedBlockHash = ts.Ts.BlockHash
	}

	// If the current L2 chain is behind of the last verified block, we skip the check.
	if s.state.GetL2Head().Number.Uint64() < lastVerifiedBlockID ||
		(s.lastInsertedBlockID != nil && s.lastInsertedBlockID.Uint64() < lastVerifiedBlockID) {
		return reorgCheckResult, nil
	}

	header, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(lastVerifiedBlockID))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch L2 header by number: %w", err)
	}

	// If the last verified block hash matches the L2 EE block hash, we skip the check.
	if header.Hash() == lastVerifiedBlockHash {
		return reorgCheckResult, nil
	}

	// If the L2 chain is on Pacaya fork.
	for lastVerifiedBlockID >= s.rpc.PacayaClients.ForkHeight {
		// If the current batch is the first Pacaya batch, we start checking the Ontake blocks.
		if lastVerifiedBatchID == s.rpc.PacayaClients.ForkHeight {
			lastVerifiedBlockID = s.rpc.PacayaClients.ForkHeight - 1
			break
		}

		batch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastVerifiedBatchID))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch batch by ID: %w", err)
		}
		previousBatch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastVerifiedBatchID-1))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch previous batch by ID: %w", err)
		}

		if batch.VerifiedTransitionId.Cmp(common.Big0) == 0 {
			lastVerifiedBatchID = previousBatch.BatchId
			lastVerifiedBlockID = previousBatch.LastBlockId
			continue
		}
		ts, err := s.rpc.PacayaClients.TaikoInbox.GetBatchVerifyingTransition(&bind.CallOpts{Context: ctx}, batch.BatchId)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch Pacaya transition: %w", err)
		}
		header, err = s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(batch.LastBlockId))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch L2 header by number: %w", err)
		}

		if header.Hash() == ts.BlockHash {
			log.Info(
				"Verified block matched, start reorging",
				"currentHeightToCheck", batch.LastBlockId,
				"chainBlockHash", header.Hash(),
				"transitionBlockHash", common.BytesToHash(ts.BlockHash[:]),
				"postPacaya", true,
			)
			reorgCheckResult.IsReorged = true
			if reorgCheckResult.L1CurrentToReset, err = s.rpc.L1.HeaderByNumber(
				ctx,
				new(big.Int).SetUint64(batch.AnchorBlockId),
			); err != nil {
				return nil, fmt.Errorf("failed to fetch L1 header by number: %w", err)
			}
			reorgCheckResult.LastHandledBlockIDToReset = header.Number
			return reorgCheckResult, nil
		}

		log.Info(
			"Verified block mismatch",
			"currentHeightToCheck", batch.LastBlockId,
			"chainBlockHash", header.Hash(),
			"transitionBlockHash", common.BytesToHash(ts.BlockHash[:]),
			"postPacaya", true,
		)

		lastVerifiedBatchID = previousBatch.BatchId
		lastVerifiedBlockID = previousBatch.LastBlockId
	}

	// Otherwise, we fetch the transition from Ontake protocol.
	for {
		// If the L2 chain is at genesis, we return the genesis L1 header to reset the L1Current cursor.
		if lastVerifiedBlockID == 0 {
			genesisL1Header, err := s.rpc.GetGenesisL1Header(ctx)
			if err != nil {
				return nil, fmt.Errorf("failed to fetch genesis L1 header: %w", err)
			}
			reorgCheckResult.IsReorged = true
			reorgCheckResult.LastHandledBlockIDToReset = common.Big0
			reorgCheckResult.L1CurrentToReset = genesisL1Header
			return reorgCheckResult, nil
		}

		currentHeightToCheck := new(big.Int).SetUint64(lastVerifiedBlockID)
		log.Info("Checking verified block mismatch", "currentHeightToCheck", currentHeightToCheck)

		blockInfo, err := s.rpc.GetL2BlockInfoV2(ctx, currentHeightToCheck)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch L2 block info: %w", err)
		}

		if blockInfo.VerifiedTransitionId.Cmp(common.Big0) == 0 {
			lastVerifiedBlockID -= 1
			continue
		}

		ts, err := s.rpc.GetTransition(ctx, currentHeightToCheck, uint32(blockInfo.VerifiedTransitionId.Uint64()))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch transition: %w", err)
		}
		header, err = s.rpc.L2.HeaderByNumber(ctx, currentHeightToCheck)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch L2 header by number: %w", err)
		}

		if ts.BlockHash == header.Hash() {
			log.Info(
				"Verified block matched, start reorging",
				"currentHeightToCheck", currentHeightToCheck,
				"chainBlockHash", header.Hash(),
				"transitionBlockHash", common.BytesToHash(ts.BlockHash[:]),
				"postPacaya", false,
			)
			reorgCheckResult.IsReorged = true
			if reorgCheckResult.L1CurrentToReset, err = s.rpc.L1.HeaderByNumber(
				ctx,
				new(big.Int).SetUint64(blockInfo.ProposedIn),
			); err != nil {
				return nil, fmt.Errorf("failed to fetch L1 header by number: %w", err)
			}
			reorgCheckResult.LastHandledBlockIDToReset = header.Number
			return reorgCheckResult, nil
		}

		log.Info(
			"Verified block mismatch",
			"currentHeightToCheck", currentHeightToCheck,
			"chainBlockHash", header.Hash(),
			"transitionBlockHash", common.BytesToHash(ts.BlockHash[:]),
			"postPacaya", false,
		)

		if lastVerifiedBlockID > reorgCheckRewindBlocks {
			lastVerifiedBlockID -= reorgCheckRewindBlocks
		} else {
			lastVerifiedBlockID = 0
		}
	}
}

// checkReorg checks whether the L1 chain has been reorged, and resets the L1Current cursor if necessary.
func (s *Syncer) checkReorg(ctx context.Context, blockID *big.Int) (*rpc.ReorgCheckResult, error) {
	// If the L2 chain is at genesis, we don't need to check L1 reorg.
	if s.state.GetL1Current().Number == s.state.GenesisL1Height {
		return new(rpc.ReorgCheckResult), nil
	}

	// 1. Check if the verified blocks in L2 EE have been reorged.
	reorgCheckResult, err := s.checkLastVerifiedBlockMismatch(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to check if the verified blocks in L2 EE have been reorged: %w", err)
	}

	// 2. If the verified blocks check is passed, we check the unverified blocks.
	if reorgCheckResult == nil || !reorgCheckResult.IsReorged {
		if reorgCheckResult, err = s.rpc.CheckL1Reorg(ctx, new(big.Int).Sub(blockID, common.Big1)); err != nil {
			return nil, fmt.Errorf("failed to check whether L1 chain has been reorged: %w", err)
		}
	}

	return reorgCheckResult, nil
}

// BlocksInserterOntake returns the Ontake blocks inserter.
func (s *Syncer) BlocksInserterOntake() *blocksInserter.BlocksInserterOntake {
	return s.blocksInserterOntake.(*blocksInserter.BlocksInserterOntake)
}

// BlocksInserterPacaya returns the Pacaya blocks inserter.
func (s *Syncer) BlocksInserterPacaya() *blocksInserter.BlocksInserterPacaya {
	return s.blocksInserterPacaya.(*blocksInserter.BlocksInserterPacaya)
}
