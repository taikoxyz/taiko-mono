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
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
type Proposer struct {
	// configurations
	*Config

	// RPC clients
	rpc *rpc.Client

	// Private keys and account addresses
	proposerAddress common.Address

	proposingTimer *time.Timer

	// Transaction builder
	txBuilder builder.ProposeBlocksTransactionBuilder

	// Protocol configurations
	protocolConfigs config.ProtocolConfigs

	chainConfig *config.ChainConfig

	lastProposedAt time.Time
	totalEpochs    uint64

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
		p.rpc.OntakeClients.ForkHeight,
		p.rpc.PacayaClients.ForkHeight,
	)
	p.txBuilder = builder.NewBuilderWithFallback(
		p.rpc,
		p.L1ProposerPrivKey,
		cfg.L2SuggestedFeeRecipient,
		cfg.TaikoL1Address,
		cfg.TaikoWrapperAddress,
		cfg.ProverSetAddress,
		cfg.ProposeBlockTxGasLimit,
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
	p.wg.Add(1)
	go p.eventLoop()
	return nil
}

// eventLoop starts the main loop of Taiko proposer.
func (p *Proposer) eventLoop() {
	defer func() {
		p.proposingTimer.Stop()
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

	// Fetch the pool content.
	preBuiltTxList, err := p.rpc.GetPoolContent(
		p.ctx,
		p.proposerAddress,
		p.protocolConfigs.BlockMaxGasLimit(),
		rpc.BlockMaxTxListBytes,
		p.LocalAddresses,
		p.MaxProposedTxListsPerEpoch,
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

	// If LocalAddressesOnly is set, filter the transactions by the local addresses.
	if p.LocalAddressesOnly {
		var (
			localTxsLists []types.Transactions
			signer        = types.LatestSignerForChainID(p.rpc.L2.ChainID)
		)
		for _, txs := range txLists {
			var filtered types.Transactions
			for _, tx := range txs {
				sender, err := types.Sender(signer, tx)
				if err != nil {
					return nil, err
				}

				for _, localAddress := range p.LocalAddresses {
					if sender == localAddress {
						filtered = append(filtered, tx)
					}
				}
			}

			if filtered.Len() != 0 {
				localTxsLists = append(localTxsLists, filtered)
			}
		}
		txLists = localTxsLists
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
// and then proposing them to TaikoL1 contract.
func (p *Proposer) ProposeOp(ctx context.Context) error {
	// Check if the preconfirmation router is set, if so, skip proposing.
	preconfRouter, err := p.rpc.GetPreconfRouterPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to fetch preconfirmation router: %w", err)
	}
	if preconfRouter != rpc.ZeroAddress {
		log.Info("Preconfirmation router is set, skip proposing", "address", preconfRouter, "time", time.Now())
		return nil
	}

	// Wait until L2 execution engine is synced at first.
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(ctx); err != nil {
		return fmt.Errorf("failed to wait until L2 execution engine synced: %w", err)
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

	l2Head, err := p.rpc.L2.BlockNumber(ctx)
	if err != nil {
		return fmt.Errorf("failed to get L2 chain head number: %w", err)
	}

	// Fetch the parent meta hash of current the L2 head, which will be used
	// by revert protection.
	parentMetaHash, err := p.GetParentMetaHash(ctx, l2Head)
	if err != nil {
		return fmt.Errorf("failed to get parent meta hash: %w", err)
	}

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
	return p.ProposeTxLists(ctx, txLists, l2Head, parentMetaHash)
}

// ProposeTxList proposes the given transactions lists to TaikoL1 smart contract.
func (p *Proposer) ProposeTxLists(
	ctx context.Context,
	txLists []types.Transactions,
	l2Head uint64,
	parentMetaHash common.Hash,
) error {
	// Check if the current L2 chain is after Pacaya fork, propose blocks batch.
	if p.chainConfig.IsPacaya(new(big.Int).SetUint64(l2Head + 1)) {
		if err := p.ProposeTxListPacaya(ctx, txLists, parentMetaHash); err != nil {
			return err
		}
		p.lastProposedAt = time.Now()
		return nil
	}

	// If the current L2 chain is after ontake fork, batch propose all L2 transactions lists.
	if err := p.ProposeTxListOntake(ctx, txLists, parentMetaHash); err != nil {
		return err
	}
	p.lastProposedAt = time.Now()
	return nil
}

// ProposeTxListOntake proposes the given transactions lists to TaikoL1 smart contract.
func (p *Proposer) ProposeTxListOntake(
	ctx context.Context,
	txLists []types.Transactions,
	parentMetaHash common.Hash,
) error {
	var (
		proverAddress     = p.proposerAddress
		txListsBytesArray [][]byte
		txNums            []int
		totalTxs          int
	)
	for _, txs := range txLists {
		txListBytes, err := rlp.EncodeToBytes(txs)
		if err != nil {
			return fmt.Errorf("failed to encode transactions: %w", err)
		}

		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			return err
		}

		txListsBytesArray = append(txListsBytesArray, compressedTxListBytes)
		txNums = append(txNums, len(txs))
		totalTxs += len(txs)
	}

	if p.Config.ClientConfig.ProverSetAddress != rpc.ZeroAddress {
		proverAddress = p.Config.ClientConfig.ProverSetAddress
	}

	ok, err := rpc.CheckProverBalance(
		ctx,
		p.rpc,
		proverAddress,
		p.TaikoL1Address,
		new(big.Int).Mul(
			p.protocolConfigs.LivenessBond(),
			new(big.Int).SetUint64(uint64(len(txLists))),
		),
	)

	if err != nil {
		log.Warn("Failed to check prover balance", "error", err)
		return err
	}

	if !ok {
		return errors.New("insufficient prover balance")
	}

	txCandidate, err := p.txBuilder.BuildOntake(ctx, txListsBytesArray, parentMetaHash)
	if err != nil {
		log.Warn("Failed to build TaikoL1.proposeBlocksV2 transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	if err := p.SendTx(ctx, txCandidate); err != nil {
		return err
	}

	log.Info("📝 Batch propose transactions succeeded", "txs", txNums)

	metrics.ProposerProposedTxListsCounter.Add(float64(len(txLists)))
	metrics.ProposerProposedTxsCounter.Add(float64(totalTxs))

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
		p.TaikoL1Address,
		new(big.Int).Add(
			p.protocolConfigs.LivenessBond(),
			new(big.Int).Mul(
				p.protocolConfigs.LivenessBondPerBlock(),
				new(big.Int).SetUint64(uint64(len(txBatch))),
			),
		),
	)

	if err != nil {
		log.Warn("Failed to check prover balance", "proposer", proposerAddress, "error", err)
		return err
	}

	if !ok {
		return fmt.Errorf("insufficient proposer (%s) balance", proposerAddress.Hex())
	}

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
			"blobHash", common.BytesToHash(forcedInclusion.BlobHash[:]),
			"feeInGwei", forcedInclusion.FeeInGwei,
			"createdAtBatchId", forcedInclusion.CreatedAtBatchId,
			"blobByteOffset", forcedInclusion.BlobByteOffset,
			"blobByteSize", forcedInclusion.BlobByteSize,
			"minTxsPerForcedInclusion", minTxsPerForcedInclusion,
		)
	}

	txCandidate, err := p.txBuilder.BuildPacaya(ctx, txBatch, forcedInclusion, minTxsPerForcedInclusion, parentMetaHash)
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
			"Failed to send TaikoL1.proposeBlockV2 / TaikoInbox.proposeBatch transaction by tx manager",
			"isPrivateMempool", isPrivate,
			"error", encoding.TryParsingCustomError(err),
		)
		if isPrivate && !errors.Is(err, context.DeadlineExceeded) {
			p.txmgrSelector.RecordPrivateTxMgrFailed()
		}
		return err
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to propose block: %s", receipt.TxHash.Hex())
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

// GetParentMetaHash returns the parent meta hash of the given L2 head.
func (p *Proposer) GetParentMetaHash(ctx context.Context, l2Head uint64) (common.Hash, error) {
	// Check if the current L2 chain is after Pacaya fork.
	if p.chainConfig.IsPacaya(new(big.Int).SetUint64(l2Head + 1)) {
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

	_, slotB, err := p.rpc.GetProtocolStateVariablesOntake(&bind.CallOpts{Context: ctx})
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to fetch protocol state variables: %w", err)
	}
	blockInfo, err := p.rpc.GetL2BlockInfoV2(ctx, new(big.Int).SetUint64(slotB.NumBlocks-1))
	if err != nil {
		return common.Hash{}, err
	}

	return blockInfo.MetaHash, nil
}
