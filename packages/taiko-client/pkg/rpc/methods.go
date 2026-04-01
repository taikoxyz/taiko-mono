package rpc

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"os"
	"reflect"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/consensus/misc"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/eth"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rpc"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	legacyBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
)

var (
	// errSyncing is returned when the L2 execution engine is syncing.
	errSyncing         = errors.New("syncing")
	rpcPollingInterval = 3 * time.Second
	defaultWaitTimeout = 3 * time.Minute
)

// GetProtocolConfigs gets the protocol configs from the inbox contract.
func (c *Client) GetProtocolConfigs(opts *bind.CallOpts) (config.ProtocolConfigs, error) {
	configs, err := c.GetProtocolConfigsShasta(opts)
	if err != nil {
		return nil, err
	}

	return config.NewShastaProtocolConfigs(configs), nil
}

// GetProtocolConfigsShasta gets the protocol configs from the inbox contract.
func (c *Client) GetProtocolConfigsShasta(opts *bind.CallOpts) (*shastaBindings.IInboxConfig, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	configs, err := c.ShastaClients.Inbox.GetConfig(opts)
	if err != nil {
		return nil, err
	}

	return &configs, nil
}

// WaitTillL2ExecutionEngineSynced keeps waiting until the L2 execution engine is fully synced.
func (c *Client) WaitTillL2ExecutionEngineSynced(ctx context.Context) error {
	start := time.Now()

	return backoff.Retry(
		func() error {
			newCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
			defer cancel()

			progress, err := c.L2ExecutionEngineSyncProgress(newCtx)
			if err != nil {
				log.Error("Fetch L2 execution engine sync progress error", "error", encoding.TryParsingCustomError(err))
				return err
			}

			if progress.IsSyncing() {
				log.Info(
					"L2 execution engine is syncing",
					"currentBlockID", progress.CurrentBlockID,
					"highestOriginBlockID", progress.HighestOriginBlockID,
					"progress", progress.SyncProgress,
					"time", time.Since(start),
				)
				return errSyncing
			}

			return nil
		},
		backoff.WithContext(backoff.NewExponentialBackOff(), ctx),
	)
}

// LatestL2KnownL1Header fetches the L2 execution engine's latest known L1 header,
// if we can't find the L1Origin data, we will use the L1 genesis header instead.
func (c *Client) LatestL2KnownL1Header(ctx context.Context) (*types.Header, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	// Try to fetch the latest known L1 header from the L2 execution engine.
	headL1Origin, err := c.L2.HeadL1Origin(ctxWithTimeout)
	if err != nil {
		switch err.Error() {
		case ethereum.NotFound.Error():
			return c.GetGenesisL1Header(ctxWithTimeout)
		default:
			return nil, err
		}
	}

	if headL1Origin == nil {
		return c.GetGenesisL1Header(ctxWithTimeout)
	}

	// Fetch the L1 header from the L1 chain.
	header, err := c.L1.HeaderByHash(ctxWithTimeout, headL1Origin.L1BlockHash)
	if err != nil {
		switch err.Error() {
		case ethereum.NotFound.Error():
			log.Warn("Latest L2 known L1 header not found, use genesis instead", "hash", headL1Origin.L1BlockHash)
			return c.GetGenesisL1Header(ctxWithTimeout)
		default:
			return nil, err
		}
	}

	log.Info("Latest L2 known L1 header", "height", header.Number, "hash", header.Hash())

	return header, nil
}

// GetGenesisL1Header fetches the L1 header that including L2 genesis block.
func (c *Client) GetGenesisL1Header(ctx context.Context) (*types.Header, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	genesisHeight, err := c.GetShastaActivationBlockNumber(ctxWithTimeout)
	if err != nil {
		return nil, err
	}

	return c.L1.HeaderByNumber(ctxWithTimeout, genesisHeight)
}

// L2ParentByCurrentBlockID fetches the block header from L2 execution engine with the largest block id that
// smaller than the given `blockId`.
func (c *Client) L2ParentByCurrentBlockID(ctx context.Context, blockID *big.Int) (*types.Header, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	var (
		parentHash    common.Hash
		parentBlockID = new(big.Int).Sub(blockID, common.Big1)
	)

	log.Debug("Get parent block by block ID", "parentBlockID", parentBlockID)

	if parentBlockID.Cmp(common.Big0) == 0 {
		return c.L2.HeaderByNumber(ctxWithTimeout, common.Big0)
	}

	l1Origin, err := c.L2.L1OriginByID(ctxWithTimeout, parentBlockID)
	if err != nil {
		if err.Error() != ethereum.NotFound.Error() {
			return nil, err
		}

		// In some cases, the L1Origin data is not found in the L2 execution engine, we will try to fetch the parent
		// by the parent block ID.
		log.Warn("L1Origin not found, try to fetch parent by ID", "blockID", parentBlockID)

		parent, err := c.L2.BlockByNumber(ctxWithTimeout, parentBlockID)
		if err != nil {
			return nil, err
		}

		parentHash = parent.Hash()
	} else {
		parentHash = l1Origin.L2BlockHash
	}

	log.Debug("Parent block L1 origin", "l1Origin", l1Origin, "parentBlockID", parentBlockID)

	return c.L2.HeaderByHash(ctxWithTimeout, parentHash)
}

// WaitL1Header keeps waiting for the L1 block header of the given block ID.
func (c *Client) WaitL1Header(ctx context.Context, blockID *big.Int) (*types.Header, error) {
	// In test environment, we will keep mining blocks until the block is found.
	if os.Getenv("RUN_TESTS") == "true" {
		for {
			head, err := c.L1.HeaderByNumber(ctx, nil)
			if err != nil {
				return nil, err
			}
			if head.Number.Cmp(blockID) >= 0 {
				return head, nil
			}

			if err := c.L1.CallContext(context.Background(), nil, "evm_mine"); err != nil {
				return nil, err
			}
		}
	}
	return waitHeader(ctx, c.L1, blockID)
}

// WaitL2Header keeps waiting for the L2 block header of the given block ID.
func (c *Client) WaitL2Header(ctx context.Context, blockID *big.Int) (*types.Header, error) {
	return waitHeader(ctx, c.L2, blockID)
}

// WaitL2Block keeps waiting for the L2 block of the given block ID.
func (c *Client) WaitL2Block(ctx context.Context, blockID *big.Int) (*types.Block, error) {
	return waitBlock(ctx, c.L2, blockID)
}

// waitForFetchResult keeps polling the provided fetch function until a non-nil
// response is returned or the context times out.
func waitForFetchResult[T any](
	ctx context.Context,
	blockID *big.Int,
	fetchFn func(context.Context, *big.Int) (T, error),
) (T, error) {
	var (
		ctxWithTimeout = ctx
		cancel         context.CancelFunc
		response       T
		emptyResponse  T
		err            error
	)

	ticker := time.NewTicker(rpcPollingInterval)
	defer ticker.Stop()

	if _, ok := ctx.Deadline(); !ok {
		ctxWithTimeout, cancel = context.WithTimeout(ctx, defaultWaitTimeout)
		defer cancel()
	}

	log.Debug("Start fetching result from execution engine", "blockID", blockID)

	for ; true; <-ticker.C {
		if ctxWithTimeout.Err() != nil {
			return emptyResponse, ctxWithTimeout.Err()
		}

		response, err = fetchFn(ctxWithTimeout, blockID)
		if err != nil {
			log.Debug(
				"Fetch result from execution engine not found, keep retrying",
				"blockID", blockID,
				"error", err,
			)
			continue
		}

		return response, nil
	}

	return emptyResponse, fmt.Errorf("failed to fetch result from L2 execution engine, blockID: %d", blockID)
}

// waitBlock keeps polling the execution engine for the given block number.
func waitBlock(ctx context.Context, ethClient *EthClient, blockID *big.Int) (*types.Block, error) {
	return waitForFetchResult(ctx, blockID, ethClient.BlockByNumber)
}

// waitHeader keeps polling the execution engine for the given block header.
func waitHeader(ctx context.Context, ethClient *EthClient, blockID *big.Int) (*types.Header, error) {
	return waitForFetchResult(ctx, blockID, ethClient.HeaderByNumber)
}

// WaitShastaHeader keeps waiting for the Shasta block header of the given batch ID from the L2 execution engine.
func (c *Client) WaitShastaHeader(ctx context.Context, batchID *big.Int) (*types.Header, error) {
	var (
		ctxWithTimeout = ctx
		cancel         context.CancelFunc
	)

	ticker := time.NewTicker(rpcPollingInterval)
	defer ticker.Stop()

	if _, ok := ctx.Deadline(); !ok {
		ctxWithTimeout, cancel = context.WithTimeout(ctx, defaultWaitTimeout)
		defer cancel()
	}

	log.Debug("Start fetching block header from L2 execution engine", "batchID", batchID)

	for ; true; <-ticker.C {
		if ctxWithTimeout.Err() != nil {
			return nil, ctxWithTimeout.Err()
		}

		l1Origin, err := c.L2Engine.LastCertainL1OriginByBatchID(ctxWithTimeout, batchID)
		if err != nil {
			log.Debug(
				"Fetch Shasta block header from L2 execution engine not found, keep retrying",
				"batchID", batchID,
				"error", err,
			)
			continue
		}

		if l1Origin == nil {
			continue
		}

		return c.L2.HeaderByHash(ctxWithTimeout, l1Origin.L2BlockHash)
	}

	return nil, fmt.Errorf("failed to fetch Shasta block header from L2 execution engine, batchID: %d", batchID)
}

// GetPoolContent fetches the transactions list from L2 execution engine's transactions pool with given
// upper limit.
func (c *Client) GetPoolContent(
	ctx context.Context,
	beneficiary common.Address,
	blockMaxGasLimit uint32,
	maxBytesPerTxList uint64,
	locals []common.Address,
	maxTransactionsLists uint64,
	minTip uint64,
	chainConfig *config.ChainConfig,
) ([]*miner.PreBuiltTxList, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()
	_ = chainConfig

	l2Head, err := c.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	baseFee, err := c.CalculateBaseFeeShasta(ctx, l2Head)
	if err != nil {
		return nil, err
	}

	var localsArg []string
	for _, local := range locals {
		localsArg = append(localsArg, local.Hex())
	}

	return c.L2Engine.TxPoolContentWithMinTip(
		ctxWithTimeout,
		beneficiary,
		baseFee,
		uint64(blockMaxGasLimit),
		maxBytesPerTxList,
		localsArg,
		maxTransactionsLists,
		minTip,
	)
}

// L2AccountNonce fetches the nonce of the given L2 account at a specified height.
func (c *Client) L2AccountNonce(
	ctx context.Context,
	account common.Address,
	blockHash common.Hash,
) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	var result hexutil.Uint64
	return uint64(result), c.L2.CallContext(
		ctxWithTimeout,
		&result,
		"eth_getTransactionCount",
		account,
		rpc.BlockNumberOrHashWithHash(blockHash, false),
	)
}

// L2SyncProgress represents the sync progress of a L2 execution engine, `ethereum.SyncProgress` is used to check
// the sync progress of verified blocks, and block IDs are used to check the sync progress of pending blocks.
type L2SyncProgress struct {
	*ethereum.SyncProgress
	CurrentBlockID       *big.Int
	HighestOriginBlockID *big.Int
}

// IsSyncing returns true if the L2 execution engine is syncing with L1.
func (p *L2SyncProgress) IsSyncing() bool {
	if p.SyncProgress == nil {
		return false
	}

	if p.CurrentBlockID == nil || p.HighestOriginBlockID == nil {
		return true
	}

	return p.CurrentBlockID.Cmp(p.HighestOriginBlockID) < 0
}

// L2ExecutionEngineSyncProgress fetches the sync progress of the given L2 execution engine.
func (c *Client) L2ExecutionEngineSyncProgress(ctx context.Context) (*L2SyncProgress, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	var (
		progress = new(L2SyncProgress)
		err      error
	)
	g, ctx := errgroup.WithContext(ctxWithTimeout)

	g.Go(func() error {
		progress.SyncProgress, err = c.L2.SyncProgress(ctx)
		return err
	})
	g.Go(func() error {
		coreState, err := c.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
		if err != nil {
			return err
		}

		// If the next proposal ID is 1, it means there is no Shasta proposal on L2 yet.
		if coreState.NextProposalId.Cmp(common.Big1) <= 0 {
			progress.HighestOriginBlockID = common.Big0
			return nil
		}

		l1Origin, err := c.L2Engine.LastL1OriginByBatchID(
			ctx,
			new(big.Int).Sub(coreState.NextProposalId, common.Big1),
		)
		if err != nil &&
			err.Error() != ethereum.NotFound.Error() &&
			err.Error() != eth.ErrProposalLastBlockUncertain.Error() {
			return err
		}
		// If the L1Origin is not found, it means the L2 execution engine has not synced yet,
		// we set the highest origin block ID to max uint64.
		if l1Origin == nil {
			progress.HighestOriginBlockID = new(big.Int).SetUint64(^uint64(0)) // Max uint64
			return nil
		}
		progress.HighestOriginBlockID = l1Origin.BlockID

		return nil
	})
	g.Go(func() error {
		headL1Origin, err := c.L2.HeadL1Origin(ctx)
		if err != nil {
			switch err.Error() {
			case ethereum.NotFound.Error():
				// There is only genesis block in the L2 execution engine, or it has not started
				// syncing the pending blocks yet.
				progress.CurrentBlockID = common.Big0
				return nil
			default:
				return err
			}
		}
		progress.CurrentBlockID = headL1Origin.BlockID
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, err
	}

	return progress, nil
}

// ReorgCheckResult represents the information about whether the L1 block has been reorged
// and how to reset the L1 cursor.
type ReorgCheckResult struct {
	IsReorged                 bool
	L1CurrentToReset          *types.Header
	LastHandledBatchIDToReset *big.Int
}

// CheckL1Reorg checks whether the L2 block's corresponding L1 block has been reorged or not.
// We will skip the reorg check if:
//  1. When the L2 chain has just finished a P2P sync, so there is no L1Origin information recorded in
//     its local database, and we assume the last verified L2 block is old enough, so its corresponding
//     L1 block should have also been finalized.
//
// Then we will check:
// 1. If the L2 block's corresponding L1 block which in L1Origin has been reorged
// 2. If the L1 information which in the given L2 block's anchor transaction has been reorged
//
// And if a reorg is detected, we return a new L1 block cursor which need to reset to.
func (c *Client) CheckL1Reorg(ctx context.Context, batchID *big.Int, isShastaBatch bool) (*ReorgCheckResult, error) {
	var (
		result                 = new(ReorgCheckResult)
		ctxWithTimeout, cancel = CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
		err                    error
	)
	defer cancel()
	_ = isShastaBatch

	if batchID.Cmp(common.Big0) == 0 {
		result.IsReorged = true
		if result.L1CurrentToReset, err = c.GetGenesisL1Header(ctxWithTimeout); err != nil {
			return nil, err
		}
		return result, nil
	}

	for {
		// If we rollback to the genesis block, then there is no L1Origin information recorded in the L2 execution
		// engine for that batch, so we will query the protocol to use `GenesisHeight` value to reset the L1 cursor.
		if batchID.Cmp(common.Big0) == 0 {
			result.IsReorged = true
			if result.L1CurrentToReset, err = c.GetGenesisL1Header(ctxWithTimeout); err != nil {
				return nil, err
			}

			return result, nil
		}

		// 1. Check whether the last L2 block's corresponding L1 block which in L1Origin has been reorged.
		l1Origin, err := c.L2Engine.LastL1OriginByBatchID(ctxWithTimeout, batchID)
		if err != nil {
			// If the L2 EE is just synced through P2P, so there is no L1Origin information recorded in
			// its local database, we skip this check.
			if err.Error() == ethereum.NotFound.Error() || err.Error() == eth.ErrProposalLastBlockUncertain.Error() {
				log.Info("L1Origin not found, the L2 execution engine has just synced from P2P network", "batchID", batchID)
				return result, nil
			}

			return nil, err
		}

		// Compare the L1 header hash in the L1Origin with the current L1 header hash in the L1 chain.
		l1Header, err := c.L1.HeaderByNumber(ctxWithTimeout, l1Origin.L1BlockHeight)
		if err != nil {
			// We can not find the L1 header which in the L1Origin, which means that L1 block has been reorged.
			if err.Error() == ethereum.NotFound.Error() {
				result.IsReorged = true
				batchID = new(big.Int).Sub(batchID, common.Big1)
				continue
			}
			return nil, fmt.Errorf("failed to fetch L1 header (%d): %w", l1Origin.L1BlockHeight, err)
		}

		if l1Header.Hash() != l1Origin.L1BlockHash {
			log.Info(
				"Reorg detected",
				"batchID", batchID,
				"l1Height", l1Origin.L1BlockHeight,
				"l1HashOld", l1Origin.L1BlockHash,
				"l1HashNew", l1Header.Hash(),
			)
			batchID = new(big.Int).Sub(batchID, common.Big1)
			result.IsReorged = true
			continue
		}

		// 2. Check whether the L1 information which in the given L2 block's anchor transaction has been reorged.
		isSyncedL1SnippetInvalid, err := c.checkSyncedL1SnippetFromAnchor(
			ctxWithTimeout,
			l1Origin.BlockID,
			l1Origin.L1BlockHeight.Uint64(),
		)
		if err != nil {
			return nil, fmt.Errorf("failed to check L1 reorg from anchor transaction: %w", err)
		}
		if isSyncedL1SnippetInvalid {
			batchID = new(big.Int).Sub(batchID, common.Big1)
			result.IsReorged = true
			continue
		}

		result.L1CurrentToReset = l1Header
		result.LastHandledBatchIDToReset = batchID
		break
	}

	log.Debug(
		"Check L1 reorg",
		"isReorged", result.IsReorged,
		"l1CurrentToResetNumber", result.L1CurrentToReset.Number,
		"l1CurrentToResetHash", result.L1CurrentToReset.Hash(),
		"batchIDToReset", result.LastHandledBatchIDToReset,
	)

	return result, nil
}

// checkSyncedL1SnippetFromAnchor checks whether the L1 snippet synced from the anchor transaction is valid.
func (c *Client) checkSyncedL1SnippetFromAnchor(
	ctx context.Context,
	blockID *big.Int,
	l1Height uint64,
) (bool, error) {
	log.Debug("Check synced L1 snippet from anchor", "blockID", blockID, "l1Height", l1Height)
	block, err := c.L2.BlockByNumber(ctx, blockID)
	if err != nil {
		log.Error("Failed to fetch L2 block", "blockID", blockID, "error", err)
		return false, err
	}
	parent, err := c.L2.BlockByHash(ctx, block.ParentHash())
	if err != nil {
		log.Error("Failed to fetch L2 parent block", "blockID", blockID, "parentHash", block.ParentHash(), "error", err)
		return false, err
	}

	l1StateRoot, l1HeightInAnchor, parentGasUsed, err := c.GetSyncedL1SnippetFromAnchor(
		block.Transactions()[0],
	)
	if err != nil {
		log.Error("Failed to parse L1 snippet from anchor transaction", "blockID", blockID, "error", err)
		return false, err
	}

	if parentGasUsed != 0 && parentGasUsed != uint32(parent.GasUsed()) {
		log.Info(
			"Reorg detected due to parent gas used mismatch",
			"blockID", blockID,
			"parentGasUsedInAnchor", parentGasUsed,
			"parentGasUsed", parent.GasUsed(),
		)
		return true, nil
	}

	l1Header, err := c.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(l1HeightInAnchor))
	if err != nil {
		log.Error("Failed to fetch L1 header", "blockID", blockID, "error", err)
		return false, err
	}

	if l1StateRoot != (common.Hash{}) && l1Header.Root != l1StateRoot {
		log.Info(
			"Reorg detected due to L1 state root mismatch",
			"blockID", blockID,
			"l1StateRootInAnchor", l1StateRoot,
			"l1StateRoot", l1Header.Root,
		)
		return true, nil
	}

	return false, nil
}

// LastL1OriginInBatchShasta fetches the L1Origin of the last block in the given Shasta batch.
func (c *Client) LastL1OriginInBatchShasta(ctx context.Context, batchID *big.Int) (*rawdb.L1Origin, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	if batchID.Cmp(common.Big0) == 0 {
		return &rawdb.L1Origin{BlockID: common.Big0}, nil
	}

	l1Origin, err := c.L2Engine.LastL1OriginByBatchID(ctxWithTimeout, batchID)
	if err != nil {
		return nil, fmt.Errorf("L1Origin not found for batch ID %d: %w", batchID, err)
	}

	return l1Origin, nil
}

// GetSyncedL1SnippetFromAnchor parses the anchor transaction calldata, and returns the synced L1 snippet,
func (c *Client) GetSyncedL1SnippetFromAnchor(tx *types.Transaction) (
	l1StateRoot common.Hash,
	l1Height uint64,
	parentGasUsed uint32,
	err error,
) {
	var method *abi.Method
	if method, err = encoding.ShastaAnchorABI.MethodById(tx.Data()); err != nil {
		if method, err = encoding.TaikoAnchorABI.MethodById(tx.Data()); err != nil {
			return common.Hash{}, 0, 0, fmt.Errorf("failed to get anchor method by ID: %w", err)
		}
	}

	var ok bool
	switch method.Name {
	case "anchorV2", "anchorV3":
		args := map[string]interface{}{}

		if err := method.Inputs.UnpackIntoMap(args, tx.Data()[4:]); err != nil {
			return common.Hash{}, 0, 0, err
		}

		l1Height, ok = args["_anchorBlockId"].(uint64)
		if !ok {
			return common.Hash{},
				0,
				0,
				errors.New("failed to parse anchorBlockId from anchorV2 / anchorV3 transaction calldata")
		}
		l1StateRoot, ok = args["_anchorStateRoot"].([32]byte)
		if !ok {
			return common.Hash{},
				0,
				0,
				errors.New("failed to parse anchorStateRoot from anchorV2 / anchorV3 transaction calldata")
		}
		parentGasUsed, ok = args["_parentGasUsed"].(uint32)
		if !ok {
			return common.Hash{},
				0,
				0,
				errors.New("failed to parse parentGasUsed from anchorV2 / anchorV3 transaction calldata")
		}
	case "anchorV4":
		args := map[string]interface{}{}

		if err := method.Inputs.UnpackIntoMap(args, tx.Data()[4:]); err != nil {
			return common.Hash{}, 0, 0, err
		}

		checkpointParams, exists := args["_checkpoint"]
		if !exists {
			return common.Hash{},
				0,
				0,
				errors.New("anchor transaction calldata missing checkpoint params")
		}

		blockValue := reflect.ValueOf(checkpointParams)
		if blockValue.Kind() != reflect.Struct {
			return common.Hash{},
				0,
				0,
				errors.New("unexpected checkpoint params type in anchor transaction calldata")
		}

		blockNumberField := blockValue.FieldByName("BlockNumber")
		if !blockNumberField.IsValid() {
			return common.Hash{},
				0,
				0,
				errors.New("anchorBlockNumber field missing in anchor transaction calldata")
		}

		blockNumber, ok := blockNumberField.Interface().(*big.Int)
		if !ok {
			return common.Hash{},
				0,
				0,
				errors.New("failed to parse anchorBlockNumber from anchor transaction calldata")
		}
		l1Height = blockNumber.Uint64()

		stateRootField := blockValue.FieldByName("StateRoot")
		if !stateRootField.IsValid() {
			return common.Hash{},
				0,
				0,
				errors.New("anchorStateRoot field missing in anchor transaction calldata")
		}

		root, ok := stateRootField.Interface().([32]byte)
		if !ok {
			return common.Hash{},
				0,
				0,
				errors.New("failed to parse anchorStateRoot from anchor transaction calldata")
		}
		l1StateRoot = root
	default:
		return common.Hash{}, 0, 0, fmt.Errorf(
			"invalid method name for anchor / anchorV2 / anchorV3 / anchorV4 transaction: %s",
			method.Name,
		)
	}

	return l1StateRoot, l1Height, parentGasUsed, nil
}

// CalculateBaseFeeShasta calculates the base fee after Shasta fork from the L2 protocol.
func (c *Client) CalculateBaseFeeShasta(ctx context.Context, l2Head *types.Header) (*big.Int, error) {
	// Return initial Shasta base fee for the first Shasta block when the Shasta fork activated from genesis.
	if l2Head.Number.Cmp(common.Big0) == 0 {
		return new(big.Int).SetUint64(params.ShastaInitialBaseFee), nil
	}

	// Otherwise, calculate Shasta base fee according to EIP-4396.
	parentBlock, err := c.L2.HeaderByHash(ctx, l2Head.ParentHash)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch parent block: %w", err)
	}
	shastaTime := uint64(0)
	config := &params.ChainConfig{ShastaTime: &shastaTime, ChainID: c.L2.ChainID}
	log.Info(
		"Params for Shasta base fee calculation",
		"parentBlockNumber", l2Head.Number,
		"parentGasLimit", l2Head.GasLimit,
		"parentGasUsed", l2Head.GasUsed,
		"parentBaseFee", l2Head.BaseFee,
		"parentTime", l2Head.Time-parentBlock.Time,
		"elasticityMultiplier", config.ElasticityMultiplier(),
		"baseFeeMaxChangeDenominator", config.BaseFeeChangeDenominator(),
		"chainID", config.ChainID,
	)
	return misc.CalcEIP4396BaseFee(config, l2Head, l2Head.Time-parentBlock.Time), nil
}

// GetShastaActivationBlockNumber resolves the L1 block number when the inbox was activated.
func (c *Client) GetShastaActivationBlockNumber(ctx context.Context) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	activationTimestamp, err := c.ShastaClients.Inbox.ActivationTimestamp(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Shasta activation timestamp: %w", err)
	}

	// If activation timestamp is zero, returns zero block number.
	if activationTimestamp.Cmp(common.Big0) == 0 || c.L1Beacon == nil {
		return common.Big0, nil
	}

	return c.L1Beacon.ExecutionBlockNumberByTimestamp(ctxWithTimeout, activationTimestamp.Uint64())
}

// GetPreconfWhiteListOperator resolves the current preconfirmation whitelist operator address.
func (c *Client) GetPreconfWhiteListOperator(opts *bind.CallOpts) (common.Address, error) {
	if c.L1Contracts.PreconfWhitelist == nil {
		return common.Address{}, errors.New("preconfirmations whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	proposer, err := c.L1Contracts.PreconfWhitelist.GetOperatorForCurrentEpoch(opts)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator: %w", err)
	}

	opInfo, err := c.L1Contracts.PreconfWhitelist.Operators(opts, proposer)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
	}

	return opInfo.SequencerAddress, nil
}

// GetNextPreconfWhiteListOperator resolves the next preconfirmation whitelist operator address.
func (c *Client) GetNextPreconfWhiteListOperator(opts *bind.CallOpts) (common.Address, error) {
	if c.L1Contracts.PreconfWhitelist == nil {
		return common.Address{}, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	proposer, err := c.L1Contracts.PreconfWhitelist.GetOperatorForNextEpoch(opts)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator: %w", err)
	}

	opInfo, err := c.L1Contracts.PreconfWhitelist.Operators(opts, proposer)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
	}

	return opInfo.SequencerAddress, nil
}

// GetAllPreconfOperators fetch all possible preconfirmation operators added to the whitelist contract,
// regardless of whether they are active or not, or eligible for the current or next epoch.
func (c *Client) GetAllPreconfOperators(opts *bind.CallOpts) ([]common.Address, error) {
	if c.L1Contracts.PreconfWhitelist == nil {
		return nil, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	count, err := c.L1Contracts.PreconfWhitelist.OperatorCount(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get total preconfirmation whitelist operators: %w", err)
	}

	var operators []common.Address
	for i := uint8(0); i < count; i++ {
		operator, err := c.L1Contracts.PreconfWhitelist.OperatorMapping(opts, big.NewInt(int64(i)))
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist operator by index %d: %w", i, err)
		}
		operators = append(operators, operator)
	}

	return operators, nil
}

// GetAllActiveOperators fetch all active preconfirmation operators added to the whitelist contract.
func (c *Client) GetAllActiveOperators(opts *bind.CallOpts) ([]common.Address, error) {
	if c.L1Contracts.PreconfWhitelist == nil {
		return nil, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	// offset=0 returns the current epoch's start timestamp.
	currentEpochTimestamp, err := c.L1Contracts.PreconfWhitelist.EpochStartTimestamp(opts, big.NewInt(0))
	if err != nil {
		return nil, fmt.Errorf("failed to get current epoch timestamp: %w", err)
	}

	count, err := c.L1Contracts.PreconfWhitelist.OperatorCount(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get total preconfirmation whitelist operators: %w", err)
	}

	var operators []common.Address
	for i := 0; i < int(count); i++ {
		proposer, err := c.L1Contracts.PreconfWhitelist.OperatorMapping(opts, big.NewInt(int64(i)))
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist proposer by index %d: %w", i, err)
		}
		opInfo, err := c.L1Contracts.PreconfWhitelist.Operators(opts, proposer)
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
		}
		if isPreconfOperatorActiveAtEpoch(opInfo.ActiveSince, opInfo.InactiveSince, currentEpochTimestamp) {
			operators = append(operators, opInfo.SequencerAddress)
		}
	}

	return operators, nil
}

func isPreconfOperatorActiveAtEpoch(activeSince, inactiveSince, currentEpochTimestamp uint32) bool {
	return inactiveSince == 0 && activeSince != 0 && activeSince <= currentEpochTimestamp
}

// GetForcedInclusion resolves the next forced inclusion, if one is available.
func (c *Client) GetForcedInclusion(ctx context.Context) (
	*legacyBindings.IForcedInclusionStoreForcedInclusion,
	*big.Int,
	error,
) {
	ctxWithTimeout, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	var (
		head uint64
		tail uint64
		err  error
	)

	g := new(errgroup.Group)
	g.Go(func() error {
		head, err = c.L1Contracts.ForcedInclusionStore.Head(&bind.CallOpts{Context: ctxWithTimeout})
		return err
	})
	g.Go(func() error {
		tail, err = c.L1Contracts.ForcedInclusionStore.Tail(&bind.CallOpts{Context: ctxWithTimeout})
		return err
	})
	if err := g.Wait(); err != nil {
		return nil, nil, encoding.TryParsingCustomError(err)
	}

	// Head is greater than or equal to tail, which means that no forced inclusion is available yet.
	if head >= tail {
		return nil, nil, nil
	}

	forcedInclusion, err := c.L1Contracts.ForcedInclusionStore.GetForcedInclusion(
		&bind.CallOpts{Context: ctxWithTimeout},
		new(big.Int).SetUint64(head),
	)
	if err != nil {
		return nil, nil, encoding.TryParsingCustomError(err)
	}

	// If there is an empty forced inclusion, we will return nil.
	if forcedInclusion.CreatedAtBatchId == 0 {
		return nil, nil, nil
	}

	minTxsPerForcedInclusion, err := c.L1Contracts.TaikoWrapper.MINTXSPERFORCEDINCLUSION(
		&bind.CallOpts{Context: ctxWithTimeout},
	)
	if err != nil {
		return nil, nil, encoding.TryParsingCustomError(err)
	}

	return &forcedInclusion, new(big.Int).SetUint64(uint64(minTxsPerForcedInclusion)), nil
}

// GetPreconfRouter resolves the preconfirmation router address.
func (c *Client) GetPreconfRouter(opts *bind.CallOpts) (common.Address, error) {
	if c.L1Contracts.TaikoWrapper == nil {
		return common.Address{}, errors.New("taikoWrapper contract is not set")
	}

	return getImmutableAddress(opts, c.L1Contracts.TaikoWrapper.PreconfRouter)
}

// GetPreconfRouterConfig returns the PreconfRouter config.
func (c *Client) GetPreconfRouterConfig(opts *bind.CallOpts) (*legacyBindings.IPreconfRouterConfig, error) {
	if c.L1Contracts.PreconfRouter == nil {
		preconfRouterAddr, err := c.GetPreconfRouter(opts)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve preconfirmation router address: %w", err)
		}

		c.L1Contracts.PreconfRouter, err = legacyBindings.NewPreconfRouter(preconfRouterAddr, c.L1)
		if err != nil {
			return nil, fmt.Errorf("failed to create preconfirmation router: %w", err)
		}
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	routerConfig, err := c.L1Contracts.PreconfRouter.GetConfig(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the PreconfRouter config: %w", err)
	}
	return &routerConfig, nil
}

// getImmutableAddress resolves an address from a contract getter.
func getImmutableAddress[T func(opts *bind.CallOpts) (common.Address, error)](
	opts *bind.CallOpts,
	resolveFunc T,
) (common.Address, error) {
	if resolveFunc == nil {
		return common.Address{}, errors.New("resolver contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return resolveFunc(opts)
}

// GetProposalHash gets the proposal hash from the inbox contract.
func (c *Client) GetProposalHash(opts *bind.CallOpts, proposalID *big.Int) (common.Hash, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.ShastaClients.Inbox.GetProposalHash(opts, proposalID)
}

// GetShastaAnchorState gets the anchor state from Shasta Anchor contract.
func (c *Client) GetShastaAnchorState(opts *bind.CallOpts) (
	*shastaBindings.AnchorBlockState,
	error,
) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	blockState, err := c.ShastaClients.Anchor.GetBlockState(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the Shasta Anchor block state: %w", err)
	}

	return &blockState, nil
}

// GetInboxConfigs gets the inbox contract configurations.
func (c *Client) GetInboxConfigs(opts *bind.CallOpts) (*shastaBindings.IInboxConfig, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	cfg, err := c.ShastaClients.Inbox.GetConfig(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the inbox config: %w", err)
	}

	return &cfg, nil
}

// GetCoreStateShasta gets the core state from the inbox contract.
func (c *Client) GetCoreStateShasta(opts *bind.CallOpts) (*shastaBindings.IInboxCoreState, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	state, err := c.ShastaClients.Inbox.GetCoreState(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the inbox core state: %w", err)
	}

	return &state, nil
}

// GetProposalByIDShasta gets the proposal by ID from the inbox contract.
func (c *Client) GetProposalByIDShasta(
	ctx context.Context,
	proposalID *big.Int,
) (*shastaBindings.ShastaInboxClientProposed, *types.Log, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	blockID, err := c.L2Engine.LastBlockIDByBatchID(ctxWithTimeout, proposalID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get last block ID by batch ID %d: %w", proposalID, err)
	}

	block, err := c.L2.BlockByNumber(ctxWithTimeout, blockID.ToInt())
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get L2 block by ID %d: %w", blockID.ToInt(), err)
	}

	_, anchorNumber, _, err := c.GetSyncedL1SnippetFromAnchor(block.Transactions()[0])
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get synced L1 snippet from anchor transaction: %w", err)
	}

	end := anchorNumber + manifest.AnchorMaxOffsetByChainID(c.L2.ChainID)
	iter, err := c.ShastaClients.Inbox.FilterProposed(&bind.FilterOpts{
		Start:   anchorNumber,
		End:     &end,
		Context: ctxWithTimeout,
	}, []*big.Int{proposalID}, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to filter proposed events from the inbox: %w", err)
	}
	defer iter.Close()

	var (
		event *shastaBindings.ShastaInboxClientProposed
		log   *types.Log
	)
	for iter.Next() {
		if iter.Event.Id.Cmp(proposalID) != 0 {
			continue
		}
		event = iter.Event
		log = &iter.Event.Raw
	}
	if event == nil || log == nil {
		return nil, nil, fmt.Errorf("proposal event not found for ID %d", proposalID)
	}

	return event, log, nil
}

// EncodeProveInput encodes the prove method input using the inbox contract.
func (c *Client) EncodeProveInput(opts *bind.CallOpts, input *shastaBindings.IInboxProveInput) ([]byte, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.ShastaClients.Inbox.EncodeProveInput(opts, *input)
}

// EncodeProposeInput encodes the propose method input using the inbox contract.
func (c *Client) EncodeProposeInput(opts *bind.CallOpts, input *shastaBindings.IInboxProposeInput) ([]byte, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.ShastaClients.Inbox.EncodeProposeInput(opts, *input)
}

// DecodeProposeInput decodes the propose method input using the inbox contract.
func (c *Client) DecodeProposeInput(opts *bind.CallOpts, data []byte) (*shastaBindings.IInboxProposeInput, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	input, err := c.ShastaClients.Inbox.DecodeProposeInput(opts, data)
	if err != nil {
		return nil, err
	}

	return &input, nil
}
