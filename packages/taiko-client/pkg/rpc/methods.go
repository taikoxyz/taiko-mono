package rpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/prysmaticlabs/prysm/v4/beacon-chain/rpc/eth/blob"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

var (
	// errSyncing is returned when the L2 execution engine is syncing.
	errSyncing        = errors.New("syncing")
	errEmptyTiersList = errors.New("empty proof tiers list in protocol")
	// syncProgressRecheckDelay is the time delay of rechecking the L2 execution engine's sync progress again,
	// if the previous check failed.
	syncProgressRecheckDelay       = 12 * time.Second
	waitL1OriginPollingInterval    = 3 * time.Second
	defaultWaitL1OriginTimeout     = 3 * time.Minute
	defaultMaxTransactionsPerBlock = uint64(149)

	// Request urls.
	sidecarsRequestURL = "eth/v1/beacon/blob_sidecars/%d"
)

// ensureGenesisMatched fetches the L2 genesis block from TaikoL1 contract,
// and checks whether the fetched genesis is same to the node local genesis.
func (c *Client) ensureGenesisMatched(ctx context.Context) error {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	stateVars, err := c.GetProtocolStateVariables(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return err
	}

	// Fetch the genesis `BlockVerified` event.
	iter, err := c.TaikoL1.FilterBlockVerified(
		&bind.FilterOpts{Start: stateVars.A.GenesisHeight, End: &stateVars.A.GenesisHeight, Context: ctxWithTimeout},
		[]*big.Int{common.Big0},
		nil,
		nil,
	)
	if err != nil {
		return err
	}

	// Fetch the node's genesis block.
	nodeGenesis, err := c.L2.HeaderByNumber(ctxWithTimeout, common.Big0)
	if err != nil {
		return err
	}

	if iter.Next() {
		l2GenesisHash := iter.Event.BlockHash

		log.Debug("Genesis hash", "node", nodeGenesis.Hash(), "TaikoL1", common.BytesToHash(l2GenesisHash[:]))

		// Node's genesis header and TaikoL1 contract's genesis header must match.
		if common.BytesToHash(l2GenesisHash[:]) != nodeGenesis.Hash() {
			return fmt.Errorf(
				"genesis header hash mismatch, node: %s, TaikoL1 contract: %s",
				nodeGenesis.Hash(),
				common.BytesToHash(l2GenesisHash[:]),
			)
		}

		return nil
	}

	log.Warn("Genesis block not found in TaikoL1")

	return nil
}

// WaitTillL2ExecutionEngineSynced keeps waiting until the L2 execution engine is fully synced.
func (c *Client) WaitTillL2ExecutionEngineSynced(ctx context.Context) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	return backoff.Retry(
		func() error {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			progress, err := c.L2ExecutionEngineSyncProgress(ctx)
			if err != nil {
				log.Error("Fetch L2 execution engine sync progress error", "error", err)
				return err
			}

			if progress.isSyncing() {
				log.Info(
					"L2 execution engine is syncing",
					"currentBlockID", progress.CurrentBlockID,
					"highestBlockID", progress.HighestBlockID,
					"progress", progress.SyncProgress,
				)
				return errSyncing
			}

			return nil
		},
		backoff.WithMaxRetries(backoff.NewConstantBackOff(syncProgressRecheckDelay), 10),
	)
}

// LatestL2KnownL1Header fetches the L2 execution engine's latest known L1 header.
func (c *Client) LatestL2KnownL1Header(ctx context.Context) (*types.Header, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

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
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	stateVars, err := c.GetProtocolStateVariables(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}

	return c.L1.HeaderByNumber(ctxWithTimeout, new(big.Int).SetUint64(stateVars.A.GenesisHeight))
}

// L2ParentByBlockID fetches the block header from L2 execution engine with the largest block id that
// smaller than the given `blockId`.
func (c *Client) L2ParentByBlockID(ctx context.Context, blockID *big.Int) (*types.Header, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	parentBlockID := new(big.Int).Sub(blockID, common.Big1)

	log.Debug("Get parent block by block ID", "parentBlockID", parentBlockID)

	if parentBlockID.Cmp(common.Big0) == 0 {
		return c.L2.HeaderByNumber(ctxWithTimeout, common.Big0)
	}

	l1Origin, err := c.L2.L1OriginByID(ctxWithTimeout, parentBlockID)
	if err != nil {
		return nil, err
	}

	log.Debug("Parent block L1 origin", "l1Origin", l1Origin, "parentBlockID", parentBlockID)

	return c.L2.HeaderByHash(ctxWithTimeout, l1Origin.L2BlockHash)
}

// WaitL1Origin keeps waiting until the L1Origin with given block ID appears on the L2 execution engine.
func (c *Client) WaitL1Origin(ctx context.Context, blockID *big.Int) (*rawdb.L1Origin, error) {
	var (
		l1Origin *rawdb.L1Origin
		err      error
	)

	ticker := time.NewTicker(waitL1OriginPollingInterval)
	defer ticker.Stop()

	var (
		ctxWithTimeout = ctx
		cancel         context.CancelFunc
	)
	if _, ok := ctx.Deadline(); !ok {
		ctxWithTimeout, cancel = context.WithTimeout(ctx, defaultWaitL1OriginTimeout)
		defer cancel()
	}

	log.Debug("Start fetching L1Origin from L2 execution engine", "blockID", blockID)
	for ; true; <-ticker.C {
		if ctxWithTimeout.Err() != nil {
			return nil, ctxWithTimeout.Err()
		}

		l1Origin, err = c.L2.L1OriginByID(ctxWithTimeout, blockID)
		if err != nil {
			log.Debug("L1Origin from L2 execution engine not found, keep retrying", "blockID", blockID, "error", err)
			continue
		}

		if l1Origin == nil {
			continue
		}

		return l1Origin, nil
	}

	return nil, fmt.Errorf("failed to fetch L1Origin from L2 execution engine, blockID: %d", blockID)
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
) ([]types.Transactions, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	l2Head, err := c.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	baseFee, err := c.TaikoL2.GetBasefee(
		&bind.CallOpts{Context: ctx},
		uint64(time.Now().Unix())-l2Head.Time,
		uint32(l2Head.GasUsed),
	)
	if err != nil {
		return nil, err
	}

	log.Info("Current base fee", "fee", baseFee)

	var localsArg []string
	for _, local := range locals {
		localsArg = append(localsArg, local.Hex())
	}

	var result []types.Transactions
	err = c.L2.CallContext(
		ctxWithTimeout,
		&result,
		"taiko_txPoolContent",
		beneficiary,
		baseFee,
		defaultMaxTransactionsPerBlock,
		blockMaxGasLimit,
		maxBytesPerTxList,
		localsArg,
		maxTransactionsLists,
	)

	return result, err
}

// L2AccountNonce fetches the nonce of the given L2 account at a specified height.
func (c *Client) L2AccountNonce(
	ctx context.Context,
	account common.Address,
	height *big.Int,
) (uint64, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var result hexutil.Uint64
	err := c.L2.CallContext(ctxWithTimeout, &result, "eth_getTransactionCount", account, hexutil.EncodeBig(height))
	return uint64(result), err
}

// L2SyncProgress represents the sync progress of a L2 execution engine, `ethereum.SyncProgress` is used to check
// the sync progress of verified blocks, and block IDs are used to check the sync progress of pending blocks.
type L2SyncProgress struct {
	*ethereum.SyncProgress
	CurrentBlockID *big.Int
	HighestBlockID *big.Int
}

// isSyncing returns true if the L2 execution engine is syncing with L1.
func (p *L2SyncProgress) isSyncing() bool {
	if p.SyncProgress == nil {
		return false
	}

	if p.CurrentBlockID == nil || p.HighestBlockID == nil {
		return true
	}

	return p.CurrentBlockID.Cmp(p.HighestBlockID) < 0
}

// L2ExecutionEngineSyncProgress fetches the sync progress of the given L2 execution engine.
func (c *Client) L2ExecutionEngineSyncProgress(ctx context.Context) (*L2SyncProgress, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
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
		stateVars, err := c.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
		if err != nil {
			return err
		}
		progress.HighestBlockID = new(big.Int).SetUint64(stateVars.B.NumBlocks - 1)
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

// GetProtocolStateVariables gets the protocol states from TaikoL1 contract.
func (c *Client) GetProtocolStateVariables(opts *bind.CallOpts) (*struct {
	A bindings.TaikoDataSlotA
	B bindings.TaikoDataSlotB
}, error) {
	if opts == nil {
		opts = &bind.CallOpts{}
	}

	var ctx = context.Background()
	if opts.Context != nil {
		ctx = opts.Context
	}
	ctxWithTimeout, cancel := context.WithTimeout(ctx, defaultWaitReceiptTimeout)
	defer cancel()
	opts.Context = ctxWithTimeout

	return GetProtocolStateVariables(c.TaikoL1, opts)
}

// CheckL1ReorgFromL2EE checks whether the L1 chain has been reorged from the L1Origin records in L2 EE,
// if so, returns the l1Current cursor and L2 blockID that need to reset to.
func (c *Client) CheckL1ReorgFromL2EE(ctx context.Context, blockID *big.Int) (bool, *types.Header, *big.Int, error) {
	var (
		reorged          bool
		l1CurrentToReset *types.Header
		blockIDToReset   *big.Int
	)
	for {
		ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
		defer cancel()

		if blockID.Cmp(common.Big0) == 0 {
			stateVars, err := c.TaikoL1.GetStateVariables(&bind.CallOpts{Context: ctxWithTimeout})
			if err != nil {
				return false, nil, nil, err
			}

			if l1CurrentToReset, err = c.L1.HeaderByNumber(
				ctxWithTimeout,
				new(big.Int).SetUint64(stateVars.A.GenesisHeight),
			); err != nil {
				return false, nil, nil, err
			}

			blockIDToReset = blockID
			break
		}

		l1Origin, err := c.L2.L1OriginByID(ctxWithTimeout, blockID)
		if err != nil {
			if err.Error() == ethereum.NotFound.Error() {
				log.Info("L1Origin not found", "blockID", blockID)

				// If the L2 EE is just synced through P2P, there is a chance that the EE do not have
				// the chain head L1Origin information recorded.
				justSyncedByP2P, err := c.IsJustSyncedByP2P(ctxWithTimeout)
				if err != nil {
					return false,
						nil,
						nil,
						fmt.Errorf("failed to check whether the L2 execution engine has just finished a P2P sync: %w", err)
				}

				log.Info(
					"Check whether the L2 execution engine has just finished a P2P sync",
					"justSyncedByP2P",
					justSyncedByP2P,
				)

				if justSyncedByP2P {
					return false, nil, nil, nil
				}

				log.Info("Reorg detected due to L1Origin not found", "blockID", blockID)
				reorged = true
				blockID = new(big.Int).Sub(blockID, common.Big1)
				continue
			}
			return false, nil, nil, err
		}

		l1Header, err := c.L1.HeaderByNumber(ctxWithTimeout, l1Origin.L1BlockHeight)
		if err != nil {
			if err.Error() == ethereum.NotFound.Error() {
				continue
			}
			return false, nil, nil, fmt.Errorf("failed to fetch L1 header (%d): %w", l1Origin.L1BlockHeight, err)
		}

		if l1Header.Hash() != l1Origin.L1BlockHash {
			log.Info(
				"Reorg detected",
				"blockID", blockID,
				"l1Height", l1Origin.L1BlockHeight,
				"l1HashOld", l1Origin.L1BlockHash,
				"l1HashNew", l1Header.Hash(),
			)
			reorged = true
			blockID = new(big.Int).Sub(blockID, common.Big1)
			continue
		}

		isSyncedL1SnippetInvalid, err := c.checkSyncedL1SnippetFromAnchor(
			ctx, blockID, l1Origin.L1BlockHeight.Uint64(),
		)
		if err != nil {
			return false, nil, nil, fmt.Errorf("failed to check L1 reorg from anchor transaction: %w", err)
		}

		if isSyncedL1SnippetInvalid {
			log.Info("Reorg detected due to invalid L1 snippet", "blockID", blockID)
			reorged = true
			blockID = new(big.Int).Sub(blockID, common.Big1)
			continue
		}

		l1CurrentToReset = l1Header
		blockIDToReset = l1Origin.BlockID
		break
	}

	log.Debug(
		"Check L1 reorg from L2 EE",
		"reorged", reorged,
		"l1CurrentToResetNumber", l1CurrentToReset.Number,
		"l1CurrentToResetHash", l1CurrentToReset.Hash(),
		"blockIDToReset", blockIDToReset,
	)

	return reorged, l1CurrentToReset, blockIDToReset, nil
}

// checkSyncedL1SnippetFromAnchor checks whether the L1 snippet synced from the anchor transaction is valid.
func (c *Client) checkSyncedL1SnippetFromAnchor(
	ctx context.Context,
	blockID *big.Int,
	l1Height uint64,
) (bool, error) {
	log.Info("Check synced L1 snippet from anchor", "blockID", blockID)
	block, err := c.L2.BlockByNumber(ctx, blockID)
	if err != nil {
		return false, err
	}
	parent, err := c.L2.BlockByHash(ctx, block.ParentHash())
	if err != nil {
		return false, err
	}

	l1BlockHash, l1StateRoot, l1HeightInAnchor, parentGasUsed, err := c.getSyncedL1SnippetFromAnchor(
		ctx,
		block.Transactions()[0],
	)
	if err != nil {
		return false, err
	}

	if l1HeightInAnchor+1 != l1Height {
		log.Info(
			"Reorg detected due to L1 height mismatch",
			"blockID", blockID,
			"l1HeightInAnchor", l1HeightInAnchor,
			"l1Height", l1Height,
		)
		return true, nil
	}

	if parentGasUsed != uint32(parent.GasUsed()) {
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
		return false, err
	}

	if l1Header.Hash() != l1BlockHash {
		log.Info(
			"Reorg detected due to L1 block hash mismatch",
			"blockID", blockID,
			"l1BlockHashInAnchor", l1BlockHash,
			"l1BlockHash", l1Header.Hash(),
		)
		return true, nil
	}

	if l1Header.Root != l1StateRoot {
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

// getSyncedL1SnippetFromAnchor parses the anchor transaction calldata, and returns the synced L1 snippet,
func (c *Client) getSyncedL1SnippetFromAnchor(
	ctx context.Context,
	tx *types.Transaction,
) (
	l1BlockHash common.Hash,
	l1StateRoot common.Hash,
	l1Height uint64,
	parentGasUsed uint32,
	err error,
) {
	method, err := encoding.TaikoL2ABI.MethodById(tx.Data())
	if err != nil {
		return common.Hash{}, common.Hash{}, 0, 0, err
	}

	if method.Name != "anchor" {
		return common.Hash{}, common.Hash{}, 0, 0, fmt.Errorf("invalid method name for anchor transaction: %s", method.Name)
	}

	args := map[string]interface{}{}

	if err := method.Inputs.UnpackIntoMap(args, tx.Data()[4:]); err != nil {
		return common.Hash{}, common.Hash{}, 0, 0, err
	}

	l1BlockHash, ok := args["_l1BlockHash"].([32]byte)
	if !ok {
		return common.Hash{},
			common.Hash{},
			0,
			0,
			fmt.Errorf("failed to parse l1BlockHash from anchor transaction calldata")
	}
	l1StateRoot, ok = args["_l1StateRoot"].([32]byte)
	if !ok {
		return common.Hash{},
			common.Hash{},
			0,
			0,
			fmt.Errorf("failed to parse l1StateRoot from anchor transaction calldata")
	}
	l1Height, ok = args["_l1BlockId"].(uint64)
	if !ok {
		return common.Hash{},
			common.Hash{},
			0,
			0,
			fmt.Errorf("failed to parse l1Height from anchor transaction calldata")
	}
	parentGasUsed, ok = args["_parentGasUsed"].(uint32)
	if !ok {
		return common.Hash{},
			common.Hash{},
			0,
			0,
			fmt.Errorf("failed to parse parentGasUsed from anchor transaction calldata")
	}

	return l1BlockHash, l1StateRoot, l1Height, parentGasUsed, nil
}

// CheckL1ReorgFromL1Cursor checks whether the L1 chain has been reorged from the given l1Current cursor,
// if so, returns the l1Current cursor that need to reset to.
func (c *Client) CheckL1ReorgFromL1Cursor(
	ctx context.Context,
	l1Current *types.Header,
	genesisHeightL1 uint64,
) (bool, *types.Header, *big.Int, error) {
	var (
		reorged          bool
		l1CurrentToReset *types.Header
	)
	for {
		ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
		defer cancel()

		if l1Current.Number.Uint64() <= genesisHeightL1 {
			newL1Current, err := c.L1.HeaderByNumber(ctxWithTimeout, new(big.Int).SetUint64(genesisHeightL1))
			if err != nil {
				return false, nil, nil, err
			}

			l1CurrentToReset = newL1Current
			break
		}

		l1Header, err := c.L1.BlockByNumber(ctxWithTimeout, l1Current.Number)
		if err != nil {
			if err.Error() == ethereum.NotFound.Error() {
				continue
			}

			return false, nil, nil, err
		}

		if l1Header.Hash() != l1Current.Hash() {
			log.Info(
				"Reorg detected",
				"l1Height", l1Current.Number,
				"l1HashOld", l1Current.Hash(),
				"l1HashNew", l1Header.Hash(),
			)
			reorged = true
			if l1Current, err = c.L1.HeaderByHash(ctxWithTimeout, l1Current.ParentHash); err != nil {
				return false, nil, nil, err
			}
			continue
		}

		l1CurrentToReset = l1Current
		break
	}

	log.Debug(
		"Check L1 reorg from l1Current cursor",
		"reorged", reorged,
		"l1CurrentToResetNumber", l1CurrentToReset.Number,
		"l1CurrentToResetHash", l1CurrentToReset.Hash(),
	)

	return reorged, l1CurrentToReset, nil, nil
}

// IsJustSyncedByP2P checks whether the given L2 execution engine has just finished a P2P
// sync.
func (c *Client) IsJustSyncedByP2P(ctx context.Context) (bool, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	l2Head, err := c.L2.HeaderByNumber(ctxWithTimeout, nil)
	if err != nil {
		return false, err
	}

	if _, err = c.L2.L1OriginByID(ctxWithTimeout, l2Head.Number); err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			return true, nil
		}

		return false, err
	}

	return false, nil
}

// TierProviderTierWithID wraps protocol ITierProviderTier struct with an ID.
type TierProviderTierWithID struct {
	ID uint16
	bindings.ITierProviderTier
}

// GetTiers fetches all protocol supported tiers.
func (c *Client) GetTiers(ctx context.Context) ([]*TierProviderTierWithID, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	tierProviderAddress, err := c.TaikoL1.Resolve0(&bind.CallOpts{Context: ctx}, StringToBytes32("tier_provider"), false)
	if err != nil {
		return nil, err
	}

	tierProvider, err := bindings.NewTierProvider(tierProviderAddress, c.L1)
	if err != nil {
		return nil, err
	}

	ids, err := tierProvider.GetTierIds(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return nil, errEmptyTiersList
	}

	var tiers []*TierProviderTierWithID
	for _, id := range ids {
		tier, err := tierProvider.GetTier(&bind.CallOpts{Context: ctxWithTimeout}, id)
		if err != nil {
			return nil, err
		}
		tiers = append(tiers, &TierProviderTierWithID{ID: id, ITierProviderTier: tier})
	}

	return tiers, nil
}

// GetBlobs fetches blobs by the given slot from a L1 consensus client.
func (c *Client) GetBlobs(ctx context.Context, slot *big.Int) ([]*blob.Sidecar, error) {
	var sidecars *blob.SidecarsResponse
	resBytes, err := c.L1Beacon.Get(ctx, fmt.Sprintf(sidecarsRequestURL, slot))
	if err != nil {
		return nil, err
	}

	return sidecars.Data, json.Unmarshal(resBytes, &sidecars)
}
