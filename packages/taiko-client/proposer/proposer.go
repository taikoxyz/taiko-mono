package proposer

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"
	"math/rand"
	"strings"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/eth"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/bridge"
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
	txBuilder builder.ProposeBatchTransactionBuilder

	// Protocol configurations
	protocolConfigs config.ProtocolConfigs

	chainConfig *config.ChainConfig

	lastProposedAt time.Time
	totalEpochs    uint64

	txmgrSelector *utils.TxMgrSelector

	ctx context.Context
	wg  sync.WaitGroup

	checkProfitability bool

	// Signal-based force proposing
	signalServiceAddress      common.Address
	lastSignalSentEventAt     time.Time
	pendingSignalForcePropose bool
	signalMu                  sync.RWMutex

	// Bridge message monitoring
	pendingBridgeMessages map[common.Hash]*types.Transaction
	bridgeMsgMu           sync.RWMutex
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
	p.checkProfitability = cfg.CheckProfitability
	if p.checkProfitability {
		log.Info("Profitability checking enabled - blocks proposed only if fees exceed costs", "checkProfitability", true)
	}

	// RPC clients
	if p.rpc, err = rpc.NewClient(p.ctx, cfg.ClientConfig); err != nil {
		return fmt.Errorf("initialize rpc clients error: %w", err)
	}

	// Check L1 RPC connection
	blockNum, err := p.rpc.L1.BlockNumber(context.Background())
	if err != nil {
		return fmt.Errorf("failed to connect to L1 RPC: %w", err)
	}
	log.Info("Successfully connected to L1 RPC", "currentBlock", blockNum)

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
	)
	p.txBuilder = builder.NewBuilderWithFallback(
		p.rpc,
		p.L1ProposerPrivKey,
		cfg.L2SuggestedFeeRecipient,
		cfg.TaikoInboxAddress,
		cfg.TaikoWrapperAddress,
		cfg.ProverSetAddress,
		cfg.SurgeProposerWrapperAddress,
		cfg.ProposeBatchTxGasLimit,
		p.chainConfig,
		p.txmgrSelector,
		cfg.RevertProtectionEnabled,
		cfg.BlobAllowed,
		cfg.FallbackToCalldata,
	)

	// Initialize SignalService address and subscription if ForceProposingDelay is enabled
	if cfg.ForceProposingDelay > 0 {
		if err := p.initSignalServiceSubscription(); err != nil {
			return err
		}
	}

	return nil
}

// initSignalServiceSubscription initializes the SignalService address and subscribes to SignalSent events
func (p *Proposer) initSignalServiceSubscription() error {
	// Get SignalService address from TaikoInbox contract
	signalServiceAddress, err := p.rpc.PacayaClients.TaikoInbox.SignalService(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return fmt.Errorf("failed to get SignalService address from TaikoInbox: %w", err)
	}

	if signalServiceAddress == (common.Address{}) {
		return fmt.Errorf("SignalService address is zero")
	}

	p.signalServiceAddress = signalServiceAddress
	log.Info("SignalService address retrieved", "address", signalServiceAddress.Hex())

	return p.subscribeToSignalSentEvent()
}

// subscribeToSignalSentEvent subscribes to SignalSent event on SignalService contract
func (p *Proposer) subscribeToSignalSentEvent() error {
	createSubscription := func() (chan types.Log, ethereum.Subscription, error) {
		logChan := make(chan types.Log)
		sub, err := p.rpc.L1.SubscribeFilterLogs(p.ctx, ethereum.FilterQuery{
			Addresses: []common.Address{p.signalServiceAddress},
			Topics: [][]common.Hash{{
				crypto.Keccak256Hash([]byte("SignalSent(address,bytes32,bytes32,bytes32)")),
			}},
		}, logChan)
		return logChan, sub, err
	}

	logChan, sub, err := createSubscription()
	if err != nil {
		return fmt.Errorf("failed to subscribe to SignalSent events on SignalService %s: %w",
			p.signalServiceAddress.Hex(), err)
	}

	p.wg.Add(1)
	go func() {
		defer p.wg.Done()
		defer sub.Unsubscribe()

		log.Info("Started SignalSent event subscription",
			"signalServiceAddress", p.signalServiceAddress.Hex(),
			"forceProposingDelay", p.Config.ForceProposingDelay,
		)

		for {
			select {
			case <-p.ctx.Done():
				log.Info("SignalSent event subscription stopped due to context cancellation")
				return
			case err := <-sub.Err():
				log.Error("SignalSent event subscription error, attempting to reconnect", "err", err)

				// Attempt to reconnect with exponential backoff, retrying indefinitely
				_ = backoff.Retry(func() error {
					newLogChan, newSub, err := createSubscription()
					if err != nil {
						log.Warn("Failed to reconnect to SignalSent events, retrying", "err", err)
						return err
					}

					log.Info("Successfully reconnected to SignalSent events")
					sub = newSub
					logChan = newLogChan
					return nil
				}, backoff.WithContext(backoff.NewExponentialBackOff(), p.ctx))
			case vLog := <-logChan:
				p.handleSignalSentEvent(vLog)
			}
		}
	}()
	return nil
}

// handleSignalSentEvent processes a SignalSent event and schedules force propose if needed
func (p *Proposer) handleSignalSentEvent(vLog types.Log) {
	log.Info("SignalSent event received",
		"txHash", vLog.TxHash.Hex(),
		"blockNumber", vLog.BlockNumber,
		"address", vLog.Address.Hex(),
	)

	p.signalMu.Lock()
	defer p.signalMu.Unlock()

	// Only process the first signal event if no pending force propose
	if !p.pendingSignalForcePropose {
		p.lastSignalSentEventAt = time.Now()
		p.pendingSignalForcePropose = true

		log.Debug("Scheduled force propose after SignalSent event",
			"delay", p.Config.ForceProposingDelay,
			"scheduledFor", time.Now().Add(p.Config.ForceProposingDelay),
		)
	} else {
		log.Debug("Ignoring subsequent SignalSent event - force propose already pending",
			"txHash", vLog.TxHash.Hex(),
			"blockNumber", vLog.BlockNumber,
		)
	}
}

// shouldForcePropose checks if we should force propose based on SignalSent events
func (p *Proposer) shouldForcePropose() (bool, string) {
	// If feature is disabled, return false
	if p.Config.ForceProposingDelay == 0 {
		return false, "force proposing after signal disabled"
	}

	p.signalMu.RLock()
	defer p.signalMu.RUnlock()

	// If no pending signal force propose, return false
	if !p.pendingSignalForcePropose {
		return false, "no pending signal force propose"
	}

	// Check if enough time has passed since the SignalSent event
	now := time.Now()
	timeSinceSignal := now.Sub(p.lastSignalSentEventAt)

	if timeSinceSignal >= p.Config.ForceProposingDelay {
		return true, fmt.Sprintf("force proposing due to SignalSent event %v ago (delay: %v)",
			timeSinceSignal, p.Config.ForceProposingDelay)
	}

	return false, fmt.Sprintf("signal received %v ago, waiting %v more",
		timeSinceSignal, p.Config.ForceProposingDelay-timeSinceSignal)
}

// resetSignalForcePropose resets the pending signal force propose state and logs if it was actually a force propose
func (p *Proposer) resetSignalForcePropose(isSignalForcePropose bool) {
	p.signalMu.Lock()
	defer p.signalMu.Unlock()
	
	hadPendingSignal := p.pendingSignalForcePropose
	p.pendingSignalForcePropose = false

	// Only log completion message if this was actually a force propose due to signal
	if isSignalForcePropose && hadPendingSignal {
		log.Info("Completed signal-based force propose")
	}
}

// Start starts the proposer's main loop.
func (p *Proposer) Start() error {
	p.wg.Add(1)
	go p.eventLoop()

	// Start monitoring L1 Bridge messages
	p.wg.Add(1)
	go p.monitorBridgeMessages()

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

// monitorBridgeMessages monitors L1 transaction pool for Bridge sendMessage calls
func (p *Proposer) monitorBridgeMessages() {
	defer p.wg.Done()

	// Create a channel for new pending transactions
	pendingTxs := make(chan common.Hash)

	// Subscribe to new pending transactions using RPC client
	sub, err := p.rpc.L1.Client.Subscribe(p.ctx, "eth", pendingTxs, "newPendingTransactions")
	if err != nil {
		log.Error("Failed to subscribe to pending transactions", "error", err)
		return
	}
	defer sub.Unsubscribe()

	// Initialize pending messages map
	p.pendingBridgeMessages = make(map[common.Hash]*types.Transaction)

	// Get the Bridge contract ABI
	bridgeABI, err := bridge.BridgeMetaData.GetAbi()
	if err != nil {
		log.Error("Failed to get Bridge ABI", "error", err)
		return
	}

	// Get the sendMessage method
	sendMessageMethod := bridgeABI.Methods["sendMessage"]
	if sendMessageMethod.ID == nil {
		log.Error("Failed to get sendMessage method ID")
		return
	}

	log.Debug("Starting Bridge message monitoring",
		"bridgeAddress", p.Config.ClientConfig.BridgeAddress.Hex(),
		"sendMessageSelector", common.BytesToHash(sendMessageMethod.ID).Hex())

	for {
		select {
		case <-p.ctx.Done():
			return
		case err := <-sub.Err():
			log.Error("Subscription error", "error", err)
			return
		case txHash := <-pendingTxs:
			log.Trace("New pending transaction detected", "hash", txHash.Hex())

			// Skip if we already have this transaction
			p.bridgeMsgMu.RLock()
			if _, exists := p.pendingBridgeMessages[txHash]; exists {
				p.bridgeMsgMu.RUnlock()
				continue
			}
			p.bridgeMsgMu.RUnlock()

			// Get transaction details
			tx, isPending, err := p.rpc.L1.TransactionByHash(p.ctx, txHash)
			if err != nil {
				log.Error("Failed to get transaction details", "hash", txHash, "error", err)
				continue
			}

			// Skip if transaction is no longer pending (as in, has been mined already) because with the fast
			// L1-to-L2 bridging, proposer will propose the sendMessage transactions as part of its block
			if !isPending {
				log.Trace("Transaction is no longer pending", "hash", txHash.Hex())
				continue
			}

			// Check if transaction is to Bridge contract
			if tx.To() == nil || *tx.To() != p.Config.ClientConfig.BridgeAddress {
				log.Trace("Transaction is not to Bridge contract", "hash", txHash.Hex())
				continue
			}

			// Check if transaction data starts with sendMessage selector
			if len(tx.Data()) < 4 || !bytes.Equal(tx.Data()[:4], sendMessageMethod.ID) {
				log.Trace("Transaction data does not start with sendMessage selector", "hash", txHash.Hex())
				log.Trace("Transaction data comparison",
					"hash", txHash.Hex(),
					"actual", common.BytesToHash(tx.Data()[:4]).Hex(),
					"expected", common.BytesToHash(sendMessageMethod.ID).Hex())
				continue
			}

			// Add to pending messages
			p.bridgeMsgMu.Lock()
			p.pendingBridgeMessages[txHash] = tx
			log.Info("New Bridge sendMessage transaction detected in mempool", "hash", txHash)
			p.bridgeMsgMu.Unlock()
		}
	}
}

// Close closes the proposer instance.
func (p *Proposer) Close(_ context.Context) {
	p.wg.Wait()
}

// fetchPoolContent fetches the transaction pool content from L2 execution engine.
func (p *Proposer) fetchPoolContent(allowEmptyPoolContent bool, l2BaseFee *big.Int) ([]types.Transactions, error) {
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
		[]common.Address{},
		p.MaxTxListsPerEpoch,
		minTip,
		l2BaseFee,
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
	// If the pool content is empty and we should propose empty blocks (either due to
	// `--epoch.minProposingInterval` timeout or signal-based force proposing), create an empty block.
	if allowEmptyPoolContent && len(txLists) == 0 {
		log.Info(
			"Pool content is empty, proposing an empty block",
			"lastProposedAt", p.lastProposedAt,
			"minProposingInterval", p.MinProposingInterval,
			"forceProposingDelay", p.ForceProposingDelay,
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

	// Get the current base fee from L2 RPC
	l2BaseFee, err := p.rpc.L2.SuggestGasPrice(ctx)
	if err != nil {
		return fmt.Errorf("failed to get base fee from L2 RPC: %w", err)
	}

	// Add pending Bridge messages to the transaction list
	txList := types.Transactions{}
	p.bridgeMsgMu.Lock()
	if len(p.pendingBridgeMessages) > 0 {
		log.Info("Pending Bridge sendMessage transactions", "count", len(p.pendingBridgeMessages))
		for _, tx := range p.pendingBridgeMessages {
			txList = append(txList, tx)
		}
		log.Debug("Added bridge message to txList", "txList", txList)
		p.pendingBridgeMessages = make(map[common.Hash]*types.Transaction) // Clear processed messages
	}
	p.bridgeMsgMu.Unlock()

	// TODO(@jmadibekov): Add a check that the transaction is valid and hasn't been mined already
	// (whether by relayer or some other way) and include it in the proposed block

	// Check whether it's time to allow proposing empty pool content. Only allows empty blocks if
	// `--epoch.minProposingInterval` is > 0 and enough time has passed since the last proposal.
	allowEmptyPoolContent := p.MinProposingInterval != 0 && time.Now().After(p.lastProposedAt.Add(p.MinProposingInterval))

	// Check if we should force propose due to SignalSent events
	shouldForcePropose, forceReason := p.shouldForcePropose()
	if shouldForcePropose {
		log.Info("Force proposing triggered by SignalSent event", "reason", forceReason)
		allowEmptyPoolContent = true // Allow empty blocks when force proposing due to signals
	}

	log.Info(
		"Start fetching L2 execution engine's transaction pool content",
		"proposer", p.proposerAddress.Hex(),
		"minProposingInterval", p.MinProposingInterval,
		"allowEmpty", allowEmptyPoolContent,
		"shouldForcePropose", shouldForcePropose,
		"forceReason", forceReason,
		"lastProposedAt", p.lastProposedAt,
	)

	// Fetch the latest parent meta hash, which will be used
	// by revert protection.
	parentMetaHash, err := p.GetParentMetaHash(ctx)
	if err != nil {
		return fmt.Errorf("failed to get parent meta hash: %w", err)
	}

	// Fetch pending L2 transactions from mempool.
	txLists, err := p.fetchPoolContent(allowEmptyPoolContent, l2BaseFee)
	if err != nil {
		return err
	}

	// If there is an empty transaction list, just return without proposing.
	if len(txLists) == 0 {
		return nil
	}

	// Propose the transactions lists.
	err = p.ProposeTxLists(ctx, txLists, parentMetaHash, l2BaseFee, shouldForcePropose)

	// If proposal was successful, reset any pending signal force propose state
	if err == nil {
		p.resetSignalForcePropose(shouldForcePropose)
	}

	return err
}

// ProposeTxList proposes the given transactions lists to TaikoInbox smart contract.
func (p *Proposer) ProposeTxLists(
	ctx context.Context,
	txLists []types.Transactions,
	parentMetaHash common.Hash,
	l2BaseFee *big.Int,
	isSignalForcePropose bool,
) error {
	if err := p.ProposeTxListPacaya(ctx, txLists, parentMetaHash, l2BaseFee, isSignalForcePropose); err != nil {
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
	l2BaseFee *big.Int,
	isSignalForcePropose bool,
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
	if p.Config.ClientConfig.SurgeProposerWrapperAddress != rpc.ZeroAddress {
		// if the proposer wrapper is set (the flag `--surgeProposerWrapper`), use it to check balance
		proposerAddress = p.Config.ClientConfig.SurgeProposerWrapperAddress
		log.Info("Using SurgeProposerWrapper for balance checking",
			"surgeProposerWrapper", proposerAddress.Hex(),
			"proposerAddress", p.proposerAddress.Hex())
	}

	ok, err := rpc.CheckProverBalance(
		ctx,
		p.rpc,
		proposerAddress,
		p.TaikoInboxAddress,
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
			"blobHash", common.BytesToHash(forcedInclusion.BlobHash[:]),
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
		l2BaseFee,
	)
	if err != nil {
		log.Warn("Failed to build TaikoInbox.proposeBatch transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	// Check profitability if enabled, but bypass check when force proposing due to signal
	if p.checkProfitability && !isSignalForcePropose {
		profitable, err := p.isProfitable(ctx, txBatch, l2BaseFee, txCandidate, txs)
		if err != nil {
			return err
		}
		if !profitable {
			log.Warn("Proposing transaction is not profitable",
				"numBatches", len(txBatch),
				"numTransactions", txs,
				"l2BaseFee", utils.WeiToEther(l2BaseFee),
			)
			return nil
		}
	} else if isSignalForcePropose {
		log.Info("Bypassing profitability check for signal-based force propose")
	}

	err = retryOnError(
		func() error {
			return p.SendTx(ctx, txCandidate)
		},
		"nonce too low",
		3,
		1*time.Second)
	if err != nil {
		return err
	}

	log.Info("📝 Propose blocks batch succeeded",
		"blocksInBatch", len(txBatch),
		"txs", txs,
		"isSignalForcePropose", isSignalForcePropose,
	)

	metrics.ProposerProposedTxListsCounter.Add(float64(len(txBatch)))
	metrics.ProposerProposedTxsCounter.Add(float64(txs))

	return nil
}

func (p *Proposer) isProfitable(
	ctx context.Context,
	txBatch []types.Transactions,
	l2BaseFee *big.Int,
	candidate *txmgr.TxCandidate,
	txs uint64,
) (bool, error) {
	estimatedCost, err := p.estimateL2Cost(ctx, candidate)
	if err != nil {
		return false, fmt.Errorf("failed to estimate L2 cost: %w", err)
	}

	collectedFees := p.computeL2Fees(txBatch, l2BaseFee)

	isProfitable := collectedFees.Cmp(estimatedCost) >= 0

	log.Info("Profitability check",
		"estimatedCost", utils.WeiToEther(estimatedCost),
		"collectedFees", utils.WeiToEther(collectedFees),
		"isProfitable", isProfitable,
		"l2BaseFee", utils.WeiToEther(l2BaseFee),
		"numBatches", len(txBatch),
		"numTransactions", txs,
	)

	return isProfitable, nil
}

func (p *Proposer) estimateL2Cost(
	ctx context.Context,
	candidate *txmgr.TxCandidate,
) (*big.Int, error) {
	// Fetch the latest L1 base fee
	feeHistory, err := p.rpc.L1.FeeHistory(ctx, 1, nil, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 base fee: %w", err)
	}

	if len(feeHistory.BaseFee) == 0 {
		return nil, fmt.Errorf("no base fee data available")
	}
	l1BaseFee := feeHistory.BaseFee[len(feeHistory.BaseFee)-1]

	blobBaseFee := new(big.Int)
	costWithBlobs := new(big.Int)
	costWithCalldata := new(big.Int)
	totalCost := new(big.Int)

	// If blobs are used, calculate batch posting cost with blobs
	if len(candidate.Blobs) > 0 {
		blobBaseFee, err = p.rpc.L1.BlobBaseFee(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to get L1 blob base fee: %w", err)
		}

		costWithBlobs = new(big.Int).Mul(
			new(big.Int).SetUint64(p.BatchPostingGasWithBlobs),
			l1BaseFee,
		)

		costOfBlobs := new(big.Int).Mul(
			blobBaseFee,
			big.NewInt(eth.BlobSize*int64(len(candidate.Blobs))),
		)

		costWithBlobs = new(big.Int).Add(
			costWithBlobs,
			costOfBlobs,
		)
		totalCost = costWithBlobs
	} else {
		// Calculate batch posting cost with calldata
		costWithCalldata = new(big.Int).Mul(
			big.NewInt(int64(p.BatchPostingGasWithCalldata)),
			l1BaseFee,
		)
		totalCost = costWithCalldata
	}

	// Add proving and proof posting cost
	totalCost.Add(totalCost, p.ProvingCostPerL2Batch)
	proofPostingCost := new(big.Int).Mul(
		big.NewInt(int64(p.ProofPostingGas)),
		l1BaseFee,
	)
	totalCost = new(big.Int).Add(totalCost, proofPostingCost)

	log.Info("L2 cost estimation",
		"l1BaseFee", utils.WeiToEther(l1BaseFee),
		"costWithCalldata", utils.WeiToEther(costWithCalldata),
		"costWithBlobs", utils.WeiToEther(costWithBlobs),
		"blobBaseFee", utils.WeiToEther(blobBaseFee),
		"proofPostingCost", utils.WeiToEther(proofPostingCost),
		"provingCostPerL2Batch", utils.WeiToEther(p.ProvingCostPerL2Batch),
		"totalCost", utils.WeiToEther(totalCost),
	)

	return totalCost, nil
}

func (p *Proposer) computeL2Fees(txBatch []types.Transactions, l2BaseFee *big.Int) *big.Int {
	baseFeeForProposer := p.getPercentageFromBaseFeeToTheProposer(l2BaseFee)

	collectedFees := new(big.Int)
	for _, txs := range txBatch {
		for _, tx := range txs {
			gasConsumed := big.NewInt(int64(tx.Gas()))
			expectedFee := new(big.Int).Mul(gasConsumed, baseFeeForProposer)
			collectedFees.Add(collectedFees, expectedFee)
		}
	}

	return collectedFees
}

func (p *Proposer) getPercentageFromBaseFeeToTheProposer(num *big.Int) *big.Int {
	if p.protocolConfigs.BaseFeeConfig().SharingPctg == 0 {
		return big.NewInt(0)
	}

	result := new(big.Int).Mul(num, big.NewInt(int64(p.protocolConfigs.BaseFeeConfig().SharingPctg)))
	return new(big.Int).Div(result, big.NewInt(100))
}

func retryOnError(operation func() error, retryon string, maxRetries int, delay time.Duration) error {
	for i := 0; i < maxRetries; i++ {
		err := operation()
		if err == nil {
			return nil // Success
		}
		if !strings.Contains(err.Error(), retryon) {
			return err // Stop retrying on unexpected errors
		}

		fmt.Printf("Retrying due to: %v (attempt %d/%d)\n", err, i+1, maxRetries)
		time.Sleep(delay)
	}
	return fmt.Errorf("operation failed after %d retries", maxRetries)
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
			"Failed to send TaikoInbox.proposeBatch transaction by tx manager",
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
