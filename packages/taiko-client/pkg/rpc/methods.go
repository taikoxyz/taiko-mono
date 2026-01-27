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
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rpc"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
)

var (
	// errSyncing is returned when the L2 execution engine is syncing.
	errSyncing         = errors.New("syncing")
	rpcPollingInterval = 3 * time.Second
	defaultWaitTimeout = 3 * time.Minute
)

// GetProtocolConfigs gets the protocol configs from Pacaya TaikoInbox contract.
func (c *Client) GetProtocolConfigs(opts *bind.CallOpts) (config.ProtocolConfigs, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	configs, err := c.PacayaClients.TaikoInbox.PacayaConfig(opts)
	if err != nil {
		return nil, err
	}

	return config.NewPacayaProtocolConfigs(&configs), nil
}

// GetProtocolConfigsShasta gets the protocol configs from Shasta Inbox contract.
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

// ensureGenesisMatched fetches the L2 genesis block from Pacaya TaikoInbox contract,
// and checks whether the fetched genesis is same to the node local genesis.
func (c *Client) ensureGenesisMatched(
	ctx context.Context,
	pacayaInbox common.Address,
) error {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	stateVars, err := c.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return err
	}

	genesisHeight := stateVars.Stats1.GenesisHeight

	// Fetch the node's genesis block.
	nodeGenesis, err := c.L2.HeaderByNumber(ctxWithTimeout, common.Big0)
	if err != nil {
		return err
	}

	log.Info("Genesis height", "height", genesisHeight, "nodeGenesisHash", nodeGenesis.Hash())

	var (
		l2GenesisHash common.Hash
		filterOpts    = &bind.FilterOpts{Start: genesisHeight, End: &genesisHeight, Context: ctxWithTimeout}
	)

	protocolConfigs, err := c.GetProtocolConfigs(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return err
	}

	// If chain actives ontake fork from genesis, we need to fetch the genesis block hash from `BlockVerifiedV2` event.
	if protocolConfigs.ForkHeightsPacaya() == 0 {
		// Fetch the genesis `BatchesVerified` event.
		log.Info("Filtering batchesVerified events from Pacaya TaikoInbox contract")
		iter, err := c.PacayaClients.TaikoInbox.FilterBatchesVerified(filterOpts)
		if err != nil {
			return err
		}
		if iter.Next() {
			l2GenesisHash = iter.Event.BlockHash
		}
		if iter.Error() != nil {
			return iter.Error()
		}
	} else if protocolConfigs.ForkHeightsOntake() == 0 {
		log.Info("Filtering blockVerifiedV2 events from Pacaya TaikoInbox contract")
		if l2GenesisHash, err = c.filterGenesisBlockVerifiedV2(ctx, filterOpts, pacayaInbox); err != nil {
			return err
		}
	} else {
		log.Info("Filtering blockVerified events from Pacaya TaikoInbox contract")
		if l2GenesisHash, err = c.filterGenesisBlockVerified(ctx, filterOpts, pacayaInbox); err != nil {
			return err
		}
	}

	log.Debug("Genesis hash", "node", nodeGenesis.Hash(), "contract", l2GenesisHash)

	if l2GenesisHash == (common.Hash{}) {
		log.Warn("Genesis block not found in Taiko contract")
		return nil
	}

	// Node's genesis header and Taiko contract's genesis header must match.
	if l2GenesisHash != nodeGenesis.Hash() {
		return fmt.Errorf(
			"genesis header hash mismatch, node: %s, Taiko contract: %s",
			nodeGenesis.Hash(),
			l2GenesisHash,
		)
	}

	return nil
}

// filterGenesisBlockVerifiedV2 fetches the genesis block verified
// event from the legacy TaikoL1 `BlockVerifiedV2` events.
func (c *Client) filterGenesisBlockVerifiedV2(
	ctx context.Context,
	ops *bind.FilterOpts,
	taikoInbox common.Address,
) (common.Hash, error) {
	client, err := ontakeBindings.NewTaikoL1Client(taikoInbox, c.L1)
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to create legacy TaikoL1 client: %w", err)
	}

	// Fetch the genesis `BlockVerifiedV2` event.
	iter, err := client.FilterBlockVerifiedV2(ops, []*big.Int{common.Big0}, nil)
	if err != nil {
		return common.Hash{}, err
	}
	if iter.Next() {
		return iter.Event.BlockHash, nil
	}
	if iter.Error() != nil {
		return common.Hash{}, iter.Error()
	}

	return common.Hash{}, fmt.Errorf("failed to find genesis block verified V2 event")
}

// filterGenesisBlockVerified fetches the genesis block verified
// event from the legacy TaikoL1 `BlockVerified` events.
func (c *Client) filterGenesisBlockVerified(
	ctx context.Context,
	ops *bind.FilterOpts,
	taikoInbox common.Address,
) (common.Hash, error) {
	client, err := ontakeBindings.NewTaikoL1Client(taikoInbox, c.L1)
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to create legacy TaikoL1 client: %w", err)
	}

	// Fetch the genesis `BlockVerified` event.
	iter, err := client.FilterBlockVerified(ops, []*big.Int{common.Big0}, nil)
	if err != nil {
		return common.Hash{}, err
	}
	if iter.Next() {
		return iter.Event.BlockHash, nil
	}
	if iter.Error() != nil {
		return common.Hash{}, iter.Error()
	}

	return common.Hash{}, fmt.Errorf("failed to find genesis block verified event")
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

	stateVars, err := c.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}

	return c.L1.HeaderByNumber(ctxWithTimeout, new(big.Int).SetUint64(stateVars.Stats1.GenesisHeight))
}

// GetBatchByID fetches the batch by ID from the Pacaya protocol.
func (c *Client) GetBatchByID(ctx context.Context, batchID *big.Int) (*pacayaBindings.ITaikoInboxBatch, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	batch, err := c.PacayaClients.TaikoInbox.GetBatch(&bind.CallOpts{Context: ctxWithTimeout}, batchID.Uint64())
	if err != nil {
		return nil, fmt.Errorf("failed to fetch batch by ID: %w", err)
	}

	return &batch, nil
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

		l1Origin, err := c.L2.LastL1OriginByBatchID(ctxWithTimeout, batchID)
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
	baseFeeConfig *pacayaBindings.LibSharedDataBaseFeeConfig,
) ([]*miner.PreBuiltTxList, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	l1Head, err := c.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}
	l2Head, err := c.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	var baseFee *big.Int
	if l1Head.Time >= c.ShastaClients.ForkTime {
		if baseFee, err = c.CalculateBaseFeeShasta(ctx, l2Head); err != nil {
			return nil, err
		}
	} else {
		if baseFee, err = c.CalculateBaseFeePacaya(ctx, l2Head, l1Head.Time, baseFeeConfig); err != nil {
			return nil, err
		}
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

		// If the next proposal ID is 1, it means there is no Shasta proposal has been made on L2 yet.
		if coreState.NextProposalId.Cmp(common.Big1) > 0 {
			l1Origin, err := c.L2.LastL1OriginByBatchID(
				ctx,
				new(big.Int).Sub(coreState.NextProposalId, common.Big1),
			)
			if err != nil && err.Error() != ethereum.NotFound.Error() {
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
		}
		// Try get the highest block ID from the Pacaya protocol state variables.
		stateVars, err := c.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
		if err != nil {
			return err
		}

		batch, err := c.PacayaClients.TaikoInbox.GetBatch(&bind.CallOpts{Context: ctx}, stateVars.Stats2.NumBatches-1)
		if err != nil {
			return err
		}

		progress.HighestOriginBlockID = new(big.Int).SetUint64(batch.LastBlockId)

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

// GetProtocolStateVariablesPacaya gets the protocol states from Pacaya TaikoInbox contract.
func (c *Client) GetProtocolStateVariablesPacaya(opts *bind.CallOpts) (*struct {
	Stats1 pacayaBindings.ITaikoInboxStats1
	Stats2 pacayaBindings.ITaikoInboxStats2
}, error) {
	if opts == nil {
		opts = &bind.CallOpts{}
	}

	var ctx = context.Background()
	if opts.Context != nil {
		ctx = opts.Context
	}
	ctxWithTimeout, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()
	opts.Context = ctxWithTimeout

	var (
		states = new(struct {
			Stats1 pacayaBindings.ITaikoInboxStats1
			Stats2 pacayaBindings.ITaikoInboxStats2
		})
		err error
	)

	g := new(errgroup.Group)
	g.Go(func() error {
		states.Stats1, err = c.PacayaClients.TaikoInbox.GetStats1(opts)
		return err
	})
	g.Go(func() error {
		states.Stats2, err = c.PacayaClients.TaikoInbox.GetStats2(opts)
		return err
	})

	return states, g.Wait()
}

// GetLastVerifiedTransitionPacaya gets the last verified transition from Pacaya TaikoInbox contract.
func (c *Client) GetLastVerifiedTransitionPacaya(ctx context.Context) (*struct {
	BatchId uint64
	BlockId uint64
	Ts      pacayaBindings.ITaikoInboxTransitionState
}, error) {
	ctxWithTimeout, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	t, err := c.PacayaClients.TaikoInbox.GetLastVerifiedTransition(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}

	return &t, nil
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

	if batchID.Cmp(common.Big0) == 0 {
		// batchID is zero already, and the given batch is a Pacaya batch, no need to check reorg.
		if !isShastaBatch || c.ShastaClients.ForkTime == 0 {
			return result, nil
		}
		if batchID, err = c.GetLastPacayaBatchID(ctxWithTimeout); err != nil {
			log.Debug("Failed to fetch last Pacaya batch ID", "error", err)
			return result, nil
		}
		isShastaBatch = false
		log.Info("Check L1 reorg from the last Pacaya batch", "batchID", batchID)
	}

	for {
		// If we rollback to the genesis block, then there is no L1Origin information recorded in the L2 execution
		// engine for that batch, so we will query the protocol to use `GenesisHeight` value to reset the L1 cursor.
		if batchID.Cmp(common.Big0) == 0 {
			if isShastaBatch {
				log.Debug("Rollback to Shasta genesis batch, check L1 reorg from the last Pacaya batch")
				if batchID, err = c.GetLastPacayaBatchID(ctxWithTimeout); err != nil {
					// If we can't find any Pacaya batch, which means Shasta fork is from genesis, we will use
					// the L1 genesis header to reset the L1 cursor.
					result.IsReorged = true
					if result.L1CurrentToReset, err = c.L1.HeaderByNumber(ctxWithTimeout, common.Big0); err != nil {
						return nil, err
					}

					return result, nil
				}

				isShastaBatch = false
				continue
			}
			genesisHeight, err := c.getGenesisHeight(ctxWithTimeout)
			if err != nil {
				return nil, err
			}

			result.IsReorged = true
			if result.L1CurrentToReset, err = c.L1.HeaderByNumber(ctxWithTimeout, genesisHeight); err != nil {
				return nil, err
			}

			return result, nil
		}

		// 1. Check whether the last L2 block's corresponding L1 block which in L1Origin has been reorged.
		var l1Origin *rawdb.L1Origin
		if isShastaBatch {
			if l1Origin, err = c.L2.LastL1OriginByBatchID(ctxWithTimeout, batchID); err != nil {
				// If the L2 EE is just synced through P2P, so there is no L1Origin information recorded in
				// its local database, we skip this check.
				if err.Error() == ethereum.NotFound.Error() {
					log.Info("L1Origin not found, the L2 execution engine has just synced from P2P network", "batchID", batchID)
					return result, nil
				}
				// If the error is taiko.ErrProposalLastBlockUncertain, return the error as well and rely on a retry.
				return nil, err
			}
		} else {
			batch, err := c.GetBatchByID(ctxWithTimeout, batchID)
			if err != nil {
				return nil, fmt.Errorf("failed to fetch batch (%d) by ID: %w", batchID, err)
			}
			if l1Origin, err = c.L2.L1OriginByID(ctxWithTimeout, new(big.Int).SetUint64(batch.LastBlockId)); err != nil {
				// If the L2 EE is just synced through P2P, so there is no L1Origin information recorded in
				// its local database, we skip this check.
				if err.Error() == ethereum.NotFound.Error() {
					log.Info("L1Origin not found, the L2 execution engine has just synced from P2P network", "batchID", batchID)
					return result, nil
				}

				return nil, err
			}
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

	// If batchID is zero, we try to fetch the last Pacaya batch's last block L1Origin.
	if batchID.Cmp(common.Big0) == 0 {
		lastPacayaBlockID, err := c.LastPacayaBlockID(ctxWithTimeout)
		if err != nil || lastPacayaBlockID.Cmp(common.Big0) == 0 {
			log.Info("Failed to fetch last Pacaya block ID, return L1Origin with zero block ID")
			return &rawdb.L1Origin{BlockID: common.Big0}, nil
		}

		l1Origin, err := c.L2.L1OriginByID(ctxWithTimeout, lastPacayaBlockID)
		if err != nil {
			return nil, fmt.Errorf("L1Origin not found for last Pacaya block ID %d: %w", lastPacayaBlockID, err)
		}
		return l1Origin, nil
	}

	l1Origin, err := c.L2.LastL1OriginByBatchID(ctxWithTimeout, batchID)
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
	config := &params.ChainConfig{ShastaTime: &c.ShastaClients.ForkTime}
	log.Info(
		"Params for Shasta base fee calculation",
		"parentBlockNumber", l2Head.Number,
		"parentGasLimit", l2Head.GasLimit,
		"parentGasUsed", l2Head.GasUsed,
		"parentBaseFee", l2Head.BaseFee,
		"parentTime", l2Head.Time-parentBlock.Time,
		"elasticityMultiplier", config.ElasticityMultiplier(),
		"baseFeeMaxChangeDenominator", config.BaseFeeChangeDenominator(),
		"shastaForkTime", c.ShastaClients.ForkTime,
	)
	return misc.CalcEIP4396BaseFee(config, l2Head, l2Head.Time-parentBlock.Time), nil
}

// CalculateBaseFeePacaya calculates the base fee after Pacaya fork from the L2 protocol.
func (c *Client) CalculateBaseFeePacaya(
	ctx context.Context,
	l2Head *types.Header,
	currentTimestamp uint64,
	baseFeeConfig *pacayaBindings.LibSharedDataBaseFeeConfig,
) (*big.Int, error) {
	log.Info(
		"Calculate base fee for the Pacaya block",
		"parentNumber", l2Head.Number,
		"parentHash", l2Head.Hash(),
		"parentGasUsed", l2Head.GasUsed,
		"currentTimestamp", currentTimestamp,
		"baseFeeConfig", baseFeeConfig,
	)

	baseFeeInfo, err := c.PacayaClients.TaikoAnchor.GetBasefeeV2(
		&bind.CallOpts{BlockNumber: l2Head.Number, BlockHash: l2Head.Hash(), Context: ctx},
		uint32(l2Head.GasUsed),
		currentTimestamp,
		*baseFeeConfig,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate pacaya block base fee by GetBasefeeV2: %w", err)
	}

	return baseFeeInfo.Basefee, nil
}

// getGenesisHeight fetches the genesis height from the protocol.
func (c *Client) getGenesisHeight(ctx context.Context) (*big.Int, error) {
	stateVars, err := c.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		return c.getShastaActivationBlockNumber(ctx)
	}

	return new(big.Int).SetUint64(stateVars.Stats1.GenesisHeight), nil
}

// getShastaActivationBlockNumber resolves the L1 block number when the Shasta inbox was activated.
func (c *Client) getShastaActivationBlockNumber(ctx context.Context) (*big.Int, error) {
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

// GetProofVerifierPacaya resolves the Pacaya proof verifier address.
func (c *Client) GetProofVerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.PacayaClients.TaikoInbox.Verifier(opts)
}

// GetPreconfWhiteListOperator resolves the current preconfirmation whitelist operator address.
func (c *Client) GetPreconfWhiteListOperator(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.PreconfWhitelist == nil {
		return common.Address{}, errors.New("preconfirmations whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	proposer, err := c.PacayaClients.PreconfWhitelist.GetOperatorForCurrentEpoch(opts)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator: %w", err)
	}

	opInfo, err := c.PacayaClients.PreconfWhitelist.Operators(opts, proposer)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
	}

	return opInfo.SequencerAddress, nil
}

// GetNextPreconfWhiteListOperator resolves the next preconfirmation whitelist operator address.
func (c *Client) GetNextPreconfWhiteListOperator(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.PreconfWhitelist == nil {
		return common.Address{}, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	proposer, err := c.PacayaClients.PreconfWhitelist.GetOperatorForNextEpoch(opts)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator: %w", err)
	}

	opInfo, err := c.PacayaClients.PreconfWhitelist.Operators(opts, proposer)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
	}

	return opInfo.SequencerAddress, nil
}

// GetAllPreconfOperators fetch all possible preconfirmation operators added to the whitelist contract,
// regardless of whether they are active or not, or eligible for the current or next epoch.
func (c *Client) GetAllPreconfOperators(opts *bind.CallOpts) ([]common.Address, error) {
	if c.PacayaClients.PreconfWhitelist == nil {
		return nil, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	count, err := c.PacayaClients.PreconfWhitelist.OperatorCount(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get total preconfirmation whitelist operators: %w", err)
	}

	var operators []common.Address
	for i := uint8(0); i < count; i++ {
		operator, err := c.PacayaClients.PreconfWhitelist.OperatorMapping(opts, big.NewInt(int64(i)))
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist operator by index %d: %w", i, err)
		}
		operators = append(operators, operator)
	}

	return operators, nil
}

// GetLastPacayaBatchID gets the last Pacaya batch ID from the protocol.
func (c *Client) GetLastPacayaBatchID(ctx context.Context) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	stateVars, err := c.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch protocol state variables from Pacaya TaikoInbox contract: %w", err)
	}

	if stateVars.Stats2.NumBatches <= 1 {
		return nil, fmt.Errorf("only genesis Pacaya batch exists")
	}

	return new(big.Int).SetUint64(stateVars.Stats2.NumBatches - 1), nil
}

// GetAllActiveOperators fetch all active preconfirmation operators added to the whitelist contract.
func (c *Client) GetAllActiveOperators(opts *bind.CallOpts) ([]common.Address, error) {
	if c.PacayaClients.PreconfWhitelist == nil {
		return nil, errors.New("preconfirmation whitelist contract is not set")
	}

	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	count, err := c.PacayaClients.PreconfWhitelist.OperatorCount(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get total preconfirmation whitelist operators: %w", err)
	}

	var operators []common.Address
	for i := 0; i < int(count); i++ {
		proposer, err := c.PacayaClients.PreconfWhitelist.OperatorMapping(opts, big.NewInt(int64(i)))
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist proposer by index %d: %w", i, err)
		}
		opInfo, err := c.PacayaClients.PreconfWhitelist.Operators(opts, proposer)
		if err != nil {
			return nil, fmt.Errorf("failed to get preconfirmation whitelist operator info: %w", err)
		}
		if opInfo.InactiveSince == 0 {
			operators = append(operators, opInfo.SequencerAddress)
		}
	}

	return operators, nil
}

// GetForcedInclusionPacaya resolves the Pacaya forced inclusion contract address.
func (c *Client) GetForcedInclusionPacaya(ctx context.Context) (
	*pacayaBindings.IForcedInclusionStoreForcedInclusion,
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
		head, err = c.PacayaClients.ForcedInclusionStore.Head(&bind.CallOpts{Context: ctxWithTimeout})
		return err
	})
	g.Go(func() error {
		tail, err = c.PacayaClients.ForcedInclusionStore.Tail(&bind.CallOpts{Context: ctxWithTimeout})
		return err
	})
	if err := g.Wait(); err != nil {
		return nil, nil, encoding.TryParsingCustomError(err)
	}

	// Head is greater than or equal to tail, which means that no forced inclusion is available yet.
	if head >= tail {
		return nil, nil, nil
	}

	forcedInclusion, err := c.PacayaClients.ForcedInclusionStore.GetForcedInclusion(
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

	minTxsPerForcedInclusion, err := c.PacayaClients.TaikoWrapper.MINTXSPERFORCEDINCLUSION(
		&bind.CallOpts{Context: ctxWithTimeout},
	)
	if err != nil {
		return nil, nil, encoding.TryParsingCustomError(err)
	}

	return &forcedInclusion, new(big.Int).SetUint64(uint64(minTxsPerForcedInclusion)), nil
}

// GetOPVerifierPacaya resolves the Pacaya op verifier address.
func (c *Client) GetOPVerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.ComposeVerifier == nil {
		return common.Address{}, errors.New("composeVerifier contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.ComposeVerifier.OpVerifier)
}

// GetSGXVerifierPacaya resolves the Pacaya sgx verifier address.
func (c *Client) GetSGXVerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.ComposeVerifier == nil {
		return common.Address{}, errors.New("composeVerifier contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.ComposeVerifier.SgxRethVerifier)
}

// GetRISC0VerifierPacaya resolves the Pacaya risc0 verifier address.
func (c *Client) GetRISC0VerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.ComposeVerifier == nil {
		return common.Address{}, errors.New("composeVerifier contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.ComposeVerifier.Risc0RethVerifier)
}

// GetSP1VerifierPacaya resolves the Pacaya sp1 verifier address.
func (c *Client) GetSP1VerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.ComposeVerifier == nil {
		return common.Address{}, errors.New("composeVerifier contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.ComposeVerifier.Sp1RethVerifier)
}

// GetSgxGethVerifierPacaya resolves the Pacaya sgx geth verifier address.
func (c *Client) GetSgxGethVerifierPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.ComposeVerifier == nil {
		return common.Address{}, errors.New("composeVerifier contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.ComposeVerifier.SgxGethVerifier)
}

// GetPreconfRouterPacaya resolves the preconfirmation router address.
func (c *Client) GetPreconfRouterPacaya(opts *bind.CallOpts) (common.Address, error) {
	if c.PacayaClients.TaikoWrapper == nil {
		return common.Address{}, errors.New("taikoWrapper contract is not set")
	}

	return getImmutableAddressPacaya(c, opts, c.PacayaClients.TaikoWrapper.PreconfRouter)
}

// GetPreconfRouterConfig returns the PreconfRouter config.
func (c *Client) GetPreconfRouterConfig(opts *bind.CallOpts) (*pacayaBindings.IPreconfRouterConfig, error) {
	if c.PacayaClients.PreconfRouter == nil {
		preconfRouterAddr, err := c.GetPreconfRouterPacaya(opts)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve preconfirmation router address: %w", err)
		}

		c.PacayaClients.PreconfRouter, err = pacayaBindings.NewPreconfRouter(preconfRouterAddr, c.L1)
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

	routerConfig, err := c.PacayaClients.PreconfRouter.GetConfig(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the PreconfRouter config: %w", err)
	}
	return &routerConfig, nil
}

// getImmutableAddressPacaya resolves the Pacaya contract address.
func getImmutableAddressPacaya[T func(opts *bind.CallOpts) (common.Address, error)](
	c *Client,
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

// GetShastaProposalHash gets the proposal hash from Shasta Inbox contract.
func (c *Client) GetShastaProposalHash(opts *bind.CallOpts, proposalID *big.Int) (common.Hash, error) {
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

// GetShastaInboxConfigs gets the Shasta Inbox contract configurations.
func (c *Client) GetShastaInboxConfigs(opts *bind.CallOpts) (*shastaBindings.IInboxConfig, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	cfg, err := c.ShastaClients.Inbox.GetConfig(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the Shasta Inbox config: %w", err)
	}

	return &cfg, nil
}

// GetCoreStateShasta gets the core state from Shasta Inbox contract.
func (c *Client) GetCoreStateShasta(opts *bind.CallOpts) (*shastaBindings.IInboxCoreState, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	state, err := c.ShastaClients.Inbox.GetCoreState(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to get the Shasta Inbox core state: %w", err)
	}

	return &state, nil
}

// GetProposalByIDShasta gets the proposal by ID from Shasta Inbox contract.
func (c *Client) GetProposalByIDShasta(
	ctx context.Context,
	proposalID *big.Int,
) (*shastaBindings.ShastaInboxClientProposed, *types.Log, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	blockID, err := c.L2.LastBlockIDByBatchID(ctxWithTimeout, proposalID)
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

	end := anchorNumber + manifest.AnchorMaxOffset
	iter, err := c.ShastaClients.Inbox.FilterProposed(&bind.FilterOpts{
		Start:   anchorNumber,
		End:     &end,
		Context: ctxWithTimeout,
	}, []*big.Int{proposalID}, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to filter proposed events from Shasta Inbox: %w", err)
	}

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

// EncodeProveInput encodes the prove method input using the Shasta Inbox contract.
func (c *Client) EncodeProveInput(opts *bind.CallOpts, input *shastaBindings.IInboxProveInput) ([]byte, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.ShastaClients.Inbox.EncodeProveInput(opts, *input)
}

// EncodeProposeInput encodes the propose method input using the Shasta Inbox contract.
func (c *Client) EncodeProposeInput(opts *bind.CallOpts, input *shastaBindings.IInboxProposeInput) ([]byte, error) {
	var cancel context.CancelFunc
	if opts == nil {
		opts = &bind.CallOpts{Context: context.Background()}
	}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, DefaultRpcTimeout)
	defer cancel()

	return c.ShastaClients.Inbox.EncodeProposeInput(opts, *input)
}

// DecodeProposeInput decodes the propose method input using the Shasta Inbox contract.
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
