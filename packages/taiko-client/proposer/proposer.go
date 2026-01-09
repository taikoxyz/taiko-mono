package proposer

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"math/rand"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

// ShastaForkBufferSeconds is the buffer time in seconds before Shasta fork time,
// to ensure no Pacaya blocks are proposed after Shasta fork time.
const shastaForkBufferSeconds = uint64(60)

// l2HeadUpdateInfo keeps track of the latest L2 head update information.
type l2HeadUpdateInfo struct {
	blockID   uint64
	updatedAt time.Time
}

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
type Proposer struct {
	// configurations
	*Config

	// RPC clients
	rpc *rpc.Client

	// Private keys and account addresses
	proposerAddress common.Address

	preconfRouterAddress common.Address

	proposingTimer *time.Timer

	// Transaction builder
	txBuilder builder.ProposeBatchTransactionBuilder

	// Protocol configurations
	protocolConfigs config.ProtocolConfigs

	chainConfig *config.ChainConfig

	lastProposedAt time.Time
	totalEpochs    uint64

	// Fallback proposer related
	l2HeadUpdate l2HeadUpdateInfo

	txmgrSelector *utils.TxMgrSelector

	ctx context.Context
	wg  sync.WaitGroup
}

// InitFromCli initializes the given proposer instance based on the command line flags.
func (p *Proposer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return p.InitFromConfig(ctx, cfg, nil, nil)
}

// InitFromConfig initializes the proposer instance based on the given configurations.
func (p *Proposer) InitFromConfig(
	ctx context.Context, cfg *Config,
	txMgr *txmgr.SimpleTxManager,
	privateTxMgr *txmgr.SimpleTxManager,
) (err error) {
	p.proposerAddress = crypto.PubkeyToAddress(cfg.L1ProposerPrivKey.PublicKey)

	log.Info("Proposer address", "address", p.proposerAddress.Hex())

	p.ctx = ctx
	p.Config = cfg
	p.lastProposedAt = time.Now()

	// RPC clients
	if p.rpc, err = rpc.NewClient(p.ctx, cfg.ClientConfig); err != nil {
		return fmt.Errorf("initialize rpc clients error: %w", err)
	}

	// Protocol configs
	if p.protocolConfigs, err = p.rpc.GetProtocolConfigs(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}
	config.ReportProtocolConfigs(p.protocolConfigs)

	if txMgr == nil {
		if txMgr, err = txmgr.NewSimpleTxManager(
			"proposer",
			log.Root(),
			&metrics.TxMgrMetrics,
			*cfg.TxmgrConfigs,
		); err != nil {
			return err
		}
	}

	if privateTxMgr == nil && cfg.PrivateTxmgrConfigs != nil && len(cfg.PrivateTxmgrConfigs.L1RPCURL) > 0 {
		if privateTxMgr, err = txmgr.NewSimpleTxManager(
			"privateMempoolProposer",
			log.Root(),
			&metrics.TxMgrMetrics,
			*cfg.PrivateTxmgrConfigs,
		); err != nil {
			return err
		}
	}

	p.txmgrSelector = utils.NewTxMgrSelector(txMgr, privateTxMgr, nil)
	p.chainConfig = config.NewChainConfig(
		p.rpc.L2.ChainID,
		p.rpc.PacayaClients.ForkHeights.Ontake,
		p.rpc.PacayaClients.ForkHeights.Pacaya,
		p.rpc.ShastaClients.ForkTime,
	)
	p.txBuilder = builder.NewBuilderWithFallback(
		p.rpc,
		p.L1ProposerPrivKey,
		cfg.L2SuggestedFeeRecipient,
		cfg.PacayaInboxAddress,
		cfg.ShastaInboxAddress,
		cfg.TaikoWrapperAddress,
		cfg.ProverSetAddress,
		cfg.ProposeBatchTxGasLimit,
		p.chainConfig,
		p.txmgrSelector,
		cfg.RevertProtectionEnabled,
		cfg.BlobAllowed,
		cfg.FallbackToCalldata,
	)

	return nil
}

// Start starts the proposer's main loop.
func (p *Proposer) Start() error {
	// get chain head and set it  to start off in case there is no new L2Heads incoming
	// for the detection of the fallback preconfer to propose.
	head, err := p.rpc.L2.HeaderByNumber(p.ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L2 head: %w", err)
	}

	p.l2HeadUpdate = l2HeadUpdateInfo{
		blockID:   head.Number.Uint64(),
		updatedAt: time.Now().UTC(),
	}

	p.wg.Add(1)
	go p.eventLoop()
	return nil
}

// eventLoop starts the main loop of Taiko proposer.
func (p *Proposer) eventLoop() {
	l2HeadCh := make(chan *types.Header, 10)
	l2HeadSub := rpc.SubscribeChainHead(p.rpc.L2, l2HeadCh)

	defer func() {
		p.proposingTimer.Stop()
		l2HeadSub.Unsubscribe()
		close(l2HeadCh)
		p.wg.Done()
	}()

	for {
		p.updateProposingTicker()

		select {
		case <-p.ctx.Done():
			return
		// proposing interval timer has been reached
		case <-p.proposingTimer.C:
			metrics.ProposerProposeEpochCounter.Add(1)
			p.totalEpochs++

			// Attempt a proposing operation
			if err := p.ProposeOp(p.ctx); err != nil {
				log.Error("Proposing operation error", "error", err)
				continue
			}
		case h := <-l2HeadCh:
			p.l2HeadUpdate = l2HeadUpdateInfo{
				blockID:   h.Number.Uint64(),
				updatedAt: time.Now().UTC(),
			}
		}
	}
}

// Close closes the proposer instance.
func (p *Proposer) Close(_ context.Context) {
	p.wg.Wait()
}

// fetchPoolContent fetches the transaction pool content from L2 execution engine.
func (p *Proposer) fetchPoolContent(allowEmptyPoolContent bool) ([]types.Transactions, error) {
	var (
		minTip  = p.MinTip
		startAt = time.Now()
	)
	// If `--epoch.allowZeroTipInterval` flag is set, allow proposing zero tip transactions once when
	// the total epochs number is divisible by the flag value.
	if p.AllowZeroTipInterval > 0 && p.totalEpochs%p.AllowZeroTipInterval == 0 {
		minTip = 0
	}

	// For Shasta proposals submission in current implementation, we always use the parent block's gas limit.
	l2Head, err := p.rpc.L2.HeaderByNumber(p.ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head: %w", err)
	}

	// Fetch the pool content.
	preBuiltTxList, err := p.rpc.GetPoolContent(
		p.ctx,
		p.proposerAddress,
		uint32(l2Head.GasLimit),
		rpc.BlockMaxTxListBytes,
		[]common.Address{},
		p.MaxTxListsPerEpoch,
		minTip,
		p.chainConfig,
		p.protocolConfigs.BaseFeeConfig(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch transaction pool content: %w", err)
	}

	poolContentFetchTime := time.Since(startAt)
	metrics.ProposerPoolContentFetchTime.Set(poolContentFetchTime.Seconds())

	// Extract the transaction lists from the pre-built transaction lists information.
	txLists := []types.Transactions{}
	for _, txs := range preBuiltTxList {
		txLists = append(txLists, txs.TxList)
	}
	// If the pool content is empty and the `--epoch.minProposingInterval` flag is set, we check
	// whether the proposer should propose an empty block.
	if allowEmptyPoolContent && len(txLists) == 0 {
		log.Info(
			"Pool content is empty, proposing an empty block",
			"lastProposedAt", p.lastProposedAt,
			"minProposingInternal", p.MinProposingInternal,
		)
		txLists = append(txLists, types.Transactions{})
	}

	log.Info(
		"Transactions lists count",
		"proposer", p.proposerAddress.Hex(),
		"count", len(txLists),
		"minTip", utils.WeiToEther(new(big.Int).SetUint64(minTip)),
		"poolContentFetchTime", poolContentFetchTime,
	)

	return txLists, nil
}

// ProposeOp performs a proposing operation, fetching transactions
// from L2 execution engine's tx pool, splitting them by proposing constraints,
// and then proposing them to TaikoInbox contract.
func (p *Proposer) ProposeOp(ctx context.Context) error {
	// Wait until L2 execution engine is synced at first.
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(ctx); err != nil {
		return fmt.Errorf("failed to wait until L2 execution engine synced: %w", err)
	}

	ok, err := p.shouldPropose(ctx)
	if err != nil {
		return fmt.Errorf("failed to check if proposer should propose: %w", err)
	} else if !ok {
		log.Info("Proposer is not allowed to propose at this time, skipping")
		return nil
	}

	// Check whether it's time to allow proposing empty pool content, if the `--epoch.minProposingInterval` flag is set.
	allowEmptyPoolContent := time.Now().After(p.lastProposedAt.Add(p.MinProposingInternal))

	log.Info(
		"Start fetching L2 execution engine's transaction pool content",
		"proposer", p.proposerAddress.Hex(),
		"minProposingInternal", p.MinProposingInternal,
		"allowEmpty", allowEmptyPoolContent,
		"lastProposedAt", p.lastProposedAt,
	)

	// Fetch pending L2 transactions from mempool.
	txLists, err := p.fetchPoolContent(allowEmptyPoolContent)
	if err != nil {
		return err
	}

	// If there is an empty transaction list, just return without proposing.
	if len(txLists) == 0 {
		return nil
	}

	// Propose the transactions lists.
	return p.ProposeTxLists(ctx, txLists)
}

// ProposeTxLists proposes the given transactions lists to TaikoInbox smart contract.
func (p *Proposer) ProposeTxLists(
	ctx context.Context,
	txLists []types.Transactions,
) error {
	l1Head, err := p.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L1 head: %w", err)
	}
	// Still in the Pacaya era.
	if l1Head.Time < p.rpc.ShastaClients.ForkTime {
		// If we are within the buffer window, pause proposing to avoid submitting Pacaya batches
		// right before the Shasta fork activates.
		if l1Head.Time+shastaForkBufferSeconds >= p.rpc.ShastaClients.ForkTime {
			log.Info(
				"Approaching Shasta fork time, waiting to switch to Shasta proposals",
				"l1HeadTime", l1Head.Time,
				"shastaForkTime", p.rpc.ShastaClients.ForkTime,
			)
			return nil
		}

		// Fetch the latest parent meta hash, which will be used by revert protection.
		parentMetaHash, err := p.GetParentMetaHash(ctx)
		if err != nil {
			return fmt.Errorf("failed to get parent meta hash: %w", err)
		}

		if err := p.ProposeTxListPacaya(ctx, txLists, parentMetaHash); err != nil {
			return err
		}
		p.lastProposedAt = time.Now()
		return nil
	}

	// We are on Shasta fork, propose a Shasta batch.
	if err := p.ProposeTxListShasta(ctx, txLists); err != nil {
		return err
	}
	p.lastProposedAt = time.Now()
	return nil
}

// ProposeTxListPacaya proposes the given transactions lists to TaikoInbox smart contract.
func (p *Proposer) ProposeTxListPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	parentMetaHash common.Hash,
) error {
	var (
		proposerAddress = p.proposerAddress
		txs             uint64
	)

	// Make sure the tx list is not bigger than the maxBlocksPerBatch.
	if len(txBatch) > p.protocolConfigs.MaxBlocksPerBatch() {
		return fmt.Errorf("tx batch size is larger than the maxBlocksPerBatch")
	}

	for _, txList := range txBatch {
		txs += uint64(len(txList))
	}

	// Check balance.
	if p.Config.ClientConfig.ProverSetAddress != rpc.ZeroAddress {
		proposerAddress = p.Config.ClientConfig.ProverSetAddress
	}

	ok, err := rpc.CheckProverBalance(
		ctx,
		p.rpc,
		proposerAddress,
		p.PacayaInboxAddress,
		new(big.Int).Add(
			p.protocolConfigs.LivenessBond(),
			new(big.Int).Mul(p.protocolConfigs.LivenessBondPerBlock(), new(big.Int).SetUint64(uint64(len(txBatch)))),
		),
	)

	if err != nil {
		log.Warn("Failed to check prover balance", "proposer", proposerAddress, "error", err)
		return err
	}

	if !ok {
		return fmt.Errorf("insufficient proposer (%s) balance", proposerAddress.Hex())
	}

	// Check forced inclusion.
	forcedInclusion, minTxsPerForcedInclusion, err := p.rpc.GetForcedInclusionPacaya(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch forced inclusion: %w", err)
	}
	if forcedInclusion == nil {
		log.Info("No forced inclusion", "proposer", proposerAddress.Hex())
	} else {
		log.Info(
			"Forced inclusion",
			"proposer", proposerAddress.Hex(),
			"blobHash", common.Hash(forcedInclusion.BlobHash),
			"feeInGwei", forcedInclusion.FeeInGwei,
			"createdAtBatchId", forcedInclusion.CreatedAtBatchId,
			"blobByteOffset", forcedInclusion.BlobByteOffset,
			"blobByteSize", forcedInclusion.BlobByteSize,
			"minTxsPerForcedInclusion", minTxsPerForcedInclusion,
		)
	}

	// Build the transaction to propose batch.
	txCandidate, err := p.txBuilder.BuildPacaya(
		ctx,
		txBatch,
		forcedInclusion,
		minTxsPerForcedInclusion,
		parentMetaHash,
		p.preconfRouterAddress,
	)
	if err != nil {
		log.Warn("Failed to build TaikoInbox.proposeBatch transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	if err := p.SendTx(ctx, txCandidate); err != nil {
		return err
	}

	log.Info("📝 Propose blocks batch succeeded", "blocksInBatch", len(txBatch), "txs", txs)

	metrics.ProposerProposedTxListsCounter.Add(float64(len(txBatch)))
	metrics.ProposerProposedTxsCounter.Add(float64(txs))

	return nil
}

// ProposeTxListShasta proposes the given transactions lists to Shasta Inbox smart contract.
func (p *Proposer) ProposeTxListShasta(ctx context.Context, txBatch []types.Transactions) error {
	var (
		txs uint64
	)

	// Make sure the tx list is not bigger than the proposalMaxBlocks.
	if len(txBatch) > manifest.ProposalMaxBlocks {
		return fmt.Errorf("tx batch size is larger than the proposalMaxBlocks")
	}

	// Count the total number of transactions.
	for _, txList := range txBatch {
		txs += uint64(len(txList))
	}

	config, err := p.rpc.GetShastaInboxConfigs(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta Inbox configs: %w", err)
	}

	// Get the last proposal to ensure we are proposing a block after its NextProposalBlockId.
	state, err := p.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta Inbox core state: %w", err)
	}

	l1Head, err := p.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L1 head: %w", err)
	}

	log.Info(
		"Last proposal",
		"id", state.LastProposalBlockId,
		"nextProposalId", state.NextProposalId,
		"l1Head", l1Head.Number,
	)

	if state.LastProposalBlockId.Cmp(l1Head.Number) >= 0 {
		if _, err = p.rpc.WaitL1Header(ctx, new(big.Int).Add(l1Head.Number, common.Big1)); err != nil {
			return fmt.Errorf("failed to wait for next L1 block: %w", err)
		}
	}

	// Build the transaction to propose batch.
	txCandidate, err := p.txBuilder.BuildShasta(
		ctx,
		txBatch,
		config.MinForcedInclusionCount,
		p.preconfRouterAddress,
	)
	if err != nil {
		log.Warn("Failed to build Shasta Inbox.propose transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	if err := p.SendTx(ctx, txCandidate); err != nil {
		return err
	}

	log.Info("📝 Propose Shasta blocks batch succeeded", "blocksInBatch", len(txBatch), "txs", txs)

	metrics.ProposerProposedTxListsCounter.Add(float64(len(txBatch)))
	metrics.ProposerProposedTxsCounter.Add(float64(txs))

	return nil
}

// updateProposingTicker updates the internal proposing timer.
func (p *Proposer) updateProposingTicker() {
	if p.proposingTimer != nil {
		p.proposingTimer.Stop()
	}

	var duration time.Duration
	if p.ProposeInterval != 0 {
		duration = p.ProposeInterval
	} else {
		// Random number between 12 - 120
		randomSeconds := rand.Intn(120-11) + 12 // nolint: gosec
		duration = time.Duration(randomSeconds) * time.Second
	}

	p.proposingTimer = time.NewTimer(duration)
}

// SendTx is the function to send a transaction with a selected tx manager.
func (p *Proposer) SendTx(ctx context.Context, txCandidate *txmgr.TxCandidate) error {
	txMgr, isPrivate := p.txmgrSelector.Select()
	receipt, err := txMgr.Send(ctx, *txCandidate)
	if err != nil {
		log.Warn(
			"Failed to send proposing batch transaction by tx manager",
			"isPrivateMempool", isPrivate,
			"error", encoding.TryParsingCustomError(err),
		)
		if isPrivate && !errors.Is(err, context.DeadlineExceeded) {
			p.txmgrSelector.RecordPrivateTxMgrFailed()
		}
		return err
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to propose batch: %s", receipt.TxHash.Hex())
	}
	return nil
}

// Name returns the application name.
func (p *Proposer) Name() string {
	return "proposer"
}

// RegisterTxMgrSelectorToBlobServer registers the tx manager selector to the given blob server,
// should only be used for testing.
func (p *Proposer) RegisterTxMgrSelectorToBlobServer(blobServer *testutils.MemoryBlobServer) {
	p.txmgrSelector = utils.NewTxMgrSelector(
		testutils.NewMemoryBlobTxMgr(p.rpc, p.txmgrSelector.TxMgr(), blobServer),
		testutils.NewMemoryBlobTxMgr(p.rpc, p.txmgrSelector.PrivateTxMgr(), blobServer),
		nil,
	)
}

// GetParentMetaHash returns the latest parent meta hash.
func (p *Proposer) GetParentMetaHash(ctx context.Context) (common.Hash, error) {
	state, err := p.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to fetch protocol state variables: %w", err)
	}

	batch, err := p.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(state.Stats2.NumBatches-1))
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to fetch batch by ID: %w", err)
	}

	return batch.MetaHash, nil
}

// shouldPropose checks whether the proposer should propose at this time.
func (p *Proposer) shouldPropose(ctx context.Context) (bool, error) {
	ctxWithTimeout, cancel := rpc.CtxWithTimeoutOrDefault(ctx, rpc.DefaultRpcTimeout)
	defer cancel()

	preconfRouterAddr, err := p.rpc.GetPreconfRouterPacaya(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return false, fmt.Errorf("failed to fetch preconfirmation router: %w", err)
	}
	if preconfRouterAddr == rpc.ZeroAddress {
		// No pre‑confirmation router → propose as normal.
		p.rpc.PacayaClients.PreconfRouter = nil
		p.preconfRouterAddress = rpc.ZeroAddress
	} else {
		p.preconfRouterAddress = preconfRouterAddr
		// if we haven't set the preconfRouter, do so now.
		if p.rpc.PacayaClients.PreconfRouter == nil {
			p.rpc.PacayaClients.PreconfRouter, err = pacayaBindings.NewPreconfRouter(preconfRouterAddr, p.rpc.L1)
			if err != nil {
				return false, fmt.Errorf("failed to create preconfirmation router: %w", err)
			}
		}

		// Check the fallback proposer address
		fallbackPreconferAddress, err := p.rpc.PacayaClients.PreconfRouter.FallbackPreconfer(
			&bind.CallOpts{Context: ctxWithTimeout},
		)
		if err != nil {
			return false, fmt.Errorf("failed to get fallback preconfer address: %w", err)
		}

		// check the active operators
		operators, err := p.rpc.GetAllActiveOperators(&bind.CallOpts{
			Context: ctx,
		})
		if err != nil {
			return false, fmt.Errorf("failed to get all active preconfer address: %w", err)
		}

		// it needs to be either us, or the proverSet we propose through
		if len(operators) != 0 ||
			(fallbackPreconferAddress != p.proposerAddress &&
				fallbackPreconferAddress != p.ProverSetAddress) {
			log.Info(
				"Preconfirmation is activated and proposer isn't the fallback preconfer, skip proposing",
				"time", time.Now(),
				"activeOperatorNums", len(operators),
			)
			return false, nil
		}

		// We need to check when the l2Head was last updated.
		if time.Since(p.l2HeadUpdate.updatedAt.UTC()) < p.FallbackTimeout {
			log.Info(
				"Fallback timeout not reached, skip proposing",
				"l2HeadUpdate", p.l2HeadUpdate.updatedAt.UTC(),
				"blockID", p.l2HeadUpdate.blockID,
				"now", time.Now().UTC(),
				"fallbackTimeout", p.FallbackTimeout,
			)
			return false, nil
		} else {
			log.Info(
				"Fallback timeout reached, proposer can propose",
				"l2HeadUpdate", p.l2HeadUpdate.updatedAt.UTC(),
				"now", time.Now().UTC(),
				"fallbackTimeout", p.FallbackTimeout,
				"blockID", p.l2HeadUpdate.blockID,
			)
			// Reset the l2HeadUpdate to avoid proposing too often.
			p.l2HeadUpdate = l2HeadUpdateInfo{blockID: 0, updatedAt: time.Now().UTC()}
		}
	}

	return true, nil
}
