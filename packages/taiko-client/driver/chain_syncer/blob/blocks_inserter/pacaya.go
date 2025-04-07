package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type insertionResult struct {
	result interface{}
	err    error
}

type taskType string

const (
	// TaskTypeInsertBlocks is the task type for inserting blocks.
	taskTypeInsertBlocks taskType = "insert_blocks"
	// TaskTypeInsertPreconfBlock is the task type for inserting preconf blocks.
	taskTypeInsertPreconfBlock taskType = "insert_preconf_block"
)

type insertionTask struct {
	name        string
	taskType    taskType
	blockNumber uint64
	blockHash   common.Hash
	parentHash  common.Hash
	f           func() (interface{}, error)
	resultCh    chan insertionResult
}

// BlocksInserterOntake is responsible for inserting Ontake blocks to the L2 execution engine.
type BlocksInserterPacaya struct {
	rpc                *rpc.Client
	progressTracker    *beaconsync.SyncProgressTracker
	blobDatasource     *rpc.BlobDataSource
	txListDecompressor *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	anchorConstructor  *anchorTxConstructor.AnchorTxConstructor // TaikoL2.anchor transactions constructor
	calldataFetcher    txlistFetcher.TxListFetcher
	blobFetcher        txlistFetcher.TxListFetcher
	insertionQueue     chan insertionTask
}

// NewBlocksInserterOntake creates a new BlocksInserterOntake instance.
func NewBlocksInserterPacaya(
	ctx context.Context,
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	txListDecompressor *txListDecompressor.TxListDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	calldataFetcher txlistFetcher.TxListFetcher,
	blobFetcher txlistFetcher.TxListFetcher,
) *BlocksInserterPacaya {
	bi := &BlocksInserterPacaya{
		rpc:                rpc,
		progressTracker:    progressTracker,
		blobDatasource:     blobDatasource,
		txListDecompressor: txListDecompressor,
		anchorConstructor:  anchorConstructor,
		calldataFetcher:    calldataFetcher,
		blobFetcher:        blobFetcher,
		insertionQueue:     make(chan insertionTask, 1024*768), // buffered channel
	}

	go bi.insertionWorker(ctx)

	return bi
}

func (i *BlocksInserterPacaya) insertionWorker(ctx context.Context) {
	// Cache for preconfirmation tasks, keyed by block number.
	pendingPreconf := make(map[uint64]insertionTask)
	for {
		select {
		case <-ctx.Done():
			return

		case task := <-i.insertionQueue:
			log.Info("Insertion task", "task", task.name)

			switch task.taskType {
			case taskTypeInsertBlocks:
				res, err := task.f()

				task.resultCh <- insertionResult{result: res, err: err}

				i.processPendingPreconf(pendingPreconf)
			case taskTypeInsertPreconfBlock:
				// Get the next expected block number.
				expected, err := i.getNextExpectedBlockNumber()
				if err != nil {
					log.Error("Error getting next expected block number", "error", err)

					task.resultCh <- insertionResult{err: err}

					continue
				}

				log.Info("Preconf block", "blockNumber", task.blockNumber, "expected", expected)

				if task.blockNumber == expected {
					// Expected block: process it.
					res, err := task.f()

					task.resultCh <- insertionResult{result: res, err: err}

					i.processPendingPreconf(pendingPreconf)
				} else if task.blockNumber > expected {
					// Not yet the expected block – cache it.
					pendingPreconf[task.blockNumber] = task
				} else {
					// If task.blockNumber < expected, it's stale.
					task.resultCh <- insertionResult{err: fmt.Errorf("stale preconf block: %d, expceted: %d", task.blockNumber, expected)}
				}
			}
		}
	}
}

// Helper function to determine the next expected preconfirmation block number.
func (i *BlocksInserterPacaya) getNextExpectedBlockNumber() (uint64, error) {
	head, err := i.rpc.L2.BlockNumber(context.Background())
	if err != nil {
		return 0, err
	}

	return head + 1, nil
}

func (i *BlocksInserterPacaya) processPendingPreconf(pending map[uint64]insertionTask) {
	log.Info("Processing pending preconf", "count", len(pending))

	for {
		expected, err := i.getNextExpectedBlockNumber()
		if err != nil {
			break
		}
		task, ok := pending[expected]
		if !ok {
			break
		}
		// Remove from pending and process.
		delete(pending, expected)
		res, err := task.f()
		task.resultCh <- insertionResult{result: res, err: err}
	}
}

// InsertBlocks inserts new Pacaya blocks to the L2 execution engine.
func (i *BlocksInserterPacaya) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) (err error) {
	task := insertionTask{
		name:     fmt.Sprintf("task-insertBlocks-%s", metadata.Pacaya().GetBatchID()), // TODO: will break if the block is not pacaya
		taskType: taskTypeInsertBlocks,
		f: func() (interface{}, error) {
			if !metadata.IsPacaya() {
				return nil, fmt.Errorf("metadata is not for Pacaya fork")
			}

			var (
				meta        = metadata.Pacaya()
				txListBytes []byte
			)

			// Fetch transactions list.
			if len(meta.GetBlobHashes()) != 0 {
				if txListBytes, err = i.blobFetcher.FetchPacaya(ctx, meta); err != nil {
					return nil, fmt.Errorf("failed to fetch tx list from blob: %w", err)
				}
			} else {
				if txListBytes, err = i.calldataFetcher.FetchPacaya(ctx, meta); err != nil {
					return nil, fmt.Errorf("failed to fetch tx list from calldata: %w", err)
				}
			}

			var (
				allTxs = i.txListDecompressor.TryDecompress(
					i.rpc.L2.ChainID,
					txListBytes,
					len(meta.GetBlobHashes()) != 0,
					true,
				)
				parent          *types.Header
				lastPayloadData *engine.ExecutableData
				txListCursor    = 0
			)

			for j, blockInfo := range meta.GetBlocks() {
				// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
				// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
				if i.progressTracker.Triggered() {
					// Already synced through beacon sync, just skip this event.
					if new(big.Int).SetUint64(meta.GetLastBlockID()).Cmp(i.progressTracker.LastSyncedBlockID()) <= 0 {
						return nil, nil
					}

					parent, err = i.rpc.L2.HeaderByHash(ctx, i.progressTracker.LastSyncedBlockHash())
				} else {
					var parentNumber *big.Int
					if lastPayloadData == nil {
						if meta.GetBatchID().Uint64() == i.rpc.PacayaClients.ForkHeight {
							parentNumber = new(big.Int).SetUint64(meta.GetBatchID().Uint64() - 1)
						} else {
							lastBatch, err := i.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(meta.GetBatchID().Uint64()-1))
							if err != nil {
								return nil, fmt.Errorf("failed to fetch last batch (%d): %w", meta.GetBatchID().Uint64()-1, err)
							}
							parentNumber = new(big.Int).SetUint64(lastBatch.LastBlockId)
						}
					} else {
						parentNumber = new(big.Int).SetUint64(lastPayloadData.Number)
					}

					parent, err = i.rpc.L2ParentByCurrentBlockID(ctx, new(big.Int).Add(parentNumber, common.Big1))
				}
				if err != nil {
					return nil, fmt.Errorf("failed to fetch L2 parent block: %w", err)
				}

				log.Debug(
					"Parent block",
					"blockID", parent.Number,
					"hash", parent.Hash(),
					"beaconSyncTriggered", i.progressTracker.Triggered(),
				)

				blockID := new(big.Int).SetUint64(parent.Number.Uint64() + 1)
				difficulty, err := encoding.CalculatePacayaDifficulty(blockID)
				if err != nil {
					return nil, fmt.Errorf("failed to calculate difficulty: %w", err)
				}
				timestamp := meta.GetLastBlockTimestamp()
				for i := len(meta.GetBlocks()) - 1; i > j; i-- {
					timestamp = timestamp - uint64(meta.GetBlocks()[i].TimeShift)
				}

				baseFee, err := i.rpc.CalculateBaseFee(
					ctx,
					parent,
					true,
					meta.GetBaseFeeConfig(),
					timestamp,
				)
				if err != nil {
					return nil, err
				}

				log.Info(
					"L2 baseFee",
					"blockID", blockID,
					"baseFee", utils.WeiToGWei(baseFee),
					"parentGasUsed", parent.GasUsed,
					"batchID", meta.GetBatchID(),
					"indexInBatch", j,
				)

				// Assemble a TaikoAnchor.anchorV3 transaction
				anchorBlockHeader, err := i.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
				if err != nil {
					return nil, fmt.Errorf("failed to fetch anchor block: %w", err)
				}

				anchorTx, err := i.anchorConstructor.AssembleAnchorV3Tx(
					ctx,
					new(big.Int).SetUint64(meta.GetAnchorBlockID()),
					anchorBlockHeader.Root,
					parent.GasUsed,
					meta.GetBaseFeeConfig(),
					meta.GetBlocks()[j].SignalSlots,
					new(big.Int).Add(parent.Number, common.Big1),
					baseFee,
				)
				if err != nil {
					return nil, fmt.Errorf("failed to create TaikoAnchor.anchorV3 transaction: %w", err)
				}

				// Get transactions in the block.
				txs := types.Transactions{}
				if txListCursor+int(blockInfo.NumTransactions) <= len(allTxs) {
					txs = allTxs[txListCursor : txListCursor+int(blockInfo.NumTransactions)]
				} else if txListCursor < len(allTxs) {
					txs = allTxs[txListCursor:]
				}

				// Decompress the transactions list and try to insert a new head block to L2 EE.
				if lastPayloadData, err = createPayloadAndSetHead(
					ctx,
					i.rpc,
					&createPayloadAndSetHeadMetaData{
						createExecutionPayloadsMetaData: &createExecutionPayloadsMetaData{
							BlockID:               blockID,
							ExtraData:             meta.GetExtraData(),
							SuggestedFeeRecipient: meta.GetCoinbase(),
							GasLimit:              uint64(meta.GetGasLimit()),
							Difficulty:            common.BytesToHash(difficulty),
							Timestamp:             timestamp,
							ParentHash:            parent.Hash(),
							L1Origin: &rawdb.L1Origin{
								BlockID:       blockID,
								L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
								L1BlockHeight: meta.GetRawBlockHeight(),
								L1BlockHash:   meta.GetRawBlockHash(),
							},
							Txs:         txs,
							Withdrawals: make([]*types.Withdrawal, 0),
							BaseFee:     baseFee,
						},
						AnchorBlockID:   new(big.Int).SetUint64(meta.GetAnchorBlockID()),
						AnchorBlockHash: meta.GetAnchorBlockHash(),
						BaseFeeConfig:   meta.GetBaseFeeConfig(),
						Parent:          parent,
					},
					anchorTx,
				); err != nil {
					return nil, fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
				}

				log.Debug("Payload data", "hash", lastPayloadData.BlockHash, "txs", len(lastPayloadData.Transactions))

				log.Info(
					"🔗 New L2 block inserted",
					"blockID", blockID,
					"hash", lastPayloadData.BlockHash,
					"transactions", len(lastPayloadData.Transactions),
					"timestamp", lastPayloadData.Timestamp,
					"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
					"withdrawals", len(lastPayloadData.Withdrawals),
					"batchID", meta.GetBatchID(),
					"indexInBatch", j,
				)

				txListCursor += int(blockInfo.NumTransactions)

				metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
			}

			return nil, nil
		},
		resultCh: make(chan insertionResult, 1),
	}

	i.insertionQueue <- task

	res := <-task.resultCh

	return res.err
}

// InsertPreconfBlockFromExecutionPayload inserts a preconf block from the given execution payload.
func (i *BlocksInserterPacaya) InsertPreconfBlockFromExecutionPayload(
	ctx context.Context,
	executableData *eth.ExecutionPayload,
) (*types.Header, error) {
	task := insertionTask{
		name:        fmt.Sprintf("task-insertPreconfBlock-%v", uint64(executableData.BlockNumber)),
		taskType:    taskTypeInsertPreconfBlock,
		blockNumber: uint64(executableData.BlockNumber),
		blockHash:   executableData.BlockHash,
		parentHash:  executableData.ParentHash,
		f: func() (interface{}, error) {
			headL1Origin, err := i.rpc.L2.HeadL1Origin(ctx)
			if err != nil && err.Error() != ethereum.NotFound.Error() {
				return nil, fmt.Errorf("failed to fetch head L1 origin: %w", err)
			}

			if headL1Origin != nil {
				if uint64(executableData.BlockNumber) <= headL1Origin.BlockID.Uint64() {
					return nil, fmt.Errorf(
						"preconfirmation block number (%d) is less than or equal to the current head L1 origin block ID (%d)",
						executableData.BlockNumber,
						headL1Origin.BlockID,
					)
				}
			}

			// compare parent hash
			parent, err := i.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(executableData.BlockNumber)-1))
			if err != nil && !errors.Is(err, ethereum.NotFound) {
				return nil, fmt.Errorf("failed to fetch parent header: %w", err)
			}

			if executableData.ParentHash != parent.Hash() {
				return nil, fmt.Errorf(
					"parent hash mismatch: %s != %s",
					executableData.ParentHash.Hex(),
					parent.Hash().Hex(),
				)
			}

			if len(executableData.Transactions) == 0 {
				return nil, fmt.Errorf("no transactions data in the payload")
			}

			var u256BaseFee = uint256.Int(executableData.BaseFeePerGas)
			payload, err := createExecutionPayloadsAndSetHead(
				ctx,
				i.rpc,
				&createExecutionPayloadsMetaData{
					BlockID:               new(big.Int).SetUint64(uint64(executableData.BlockNumber)),
					ExtraData:             executableData.ExtraData,
					SuggestedFeeRecipient: executableData.FeeRecipient,
					GasLimit:              uint64(executableData.GasLimit),
					Difficulty:            common.Hash(executableData.PrevRandao),
					Timestamp:             uint64(executableData.Timestamp),
					ParentHash:            executableData.ParentHash,
					L1Origin: &rawdb.L1Origin{
						BlockID:       new(big.Int).SetUint64(uint64(executableData.BlockNumber)),
						L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
						L1BlockHeight: nil,
						L1BlockHash:   common.Hash{},
					},
					BaseFee:     u256BaseFee.ToBig(),
					Withdrawals: make([]*types.Withdrawal, 0),
				},
				executableData.Transactions[0],
			)
			if err != nil {
				return nil, fmt.Errorf("failed to create execution data: %w", err)
			}

			metrics.DriverL2PreconfHeadHeightGauge.Set(float64(executableData.BlockNumber))

			header, err := i.rpc.L2.HeaderByHash(ctx, payload.BlockHash)
			if err != nil {
				return nil, err
			}

			return header, nil
		},
		resultCh: make(chan insertionResult, 1),
	}

	i.insertionQueue <- task

	res := <-task.resultCh
	if res.err != nil {
		return nil, res.err
	}

	header, ok := res.result.(*types.Header)
	if !ok {
		return nil, fmt.Errorf("unexpected result type")
	}

	return header, nil
}

// RemovePreconfBlocks removes preconf blocks from the L2 execution engine.
func (i *BlocksInserterPacaya) RemovePreconfBlocks(ctx context.Context, newLastBlockID uint64) error {
	newHead, err := i.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(newLastBlockID))
	if err != nil {
		return err
	}

	fc := &engine.ForkchoiceStateV1{HeadBlockHash: newHead.Hash()}
	fcRes, err := i.rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
	if err != nil {
		return err
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	return nil
}
