package proposer

import (
	"bytes"
	"context"
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
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/urfave/cli/v2"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	selector "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/prover_selector"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

var (
	proverAssignmentTimeout    = 30 * time.Minute
	requestProverServerTimeout = 12 * time.Second
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

	tiers    []*rpc.TierProviderTierWithID
	tierFees []encoding.TierFee

	// Prover selector
	proverSelector selector.ProverSelector

	// Transaction builder
	txBuilder builder.ProposeBlockTransactionBuilder

	// Protocol configurations
	protocolConfigs *bindings.TaikoDataConfig

	lastProposedAt time.Time

	txmgr *txmgr.SimpleTxManager

	ctx context.Context
	wg  sync.WaitGroup
}

// InitFromCli New initializes the given proposer instance based on the command line flags.
func (p *Proposer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return p.InitFromConfig(ctx, cfg)
}

// InitFromConfig initializes the proposer instance based on the given configurations.
func (p *Proposer) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	p.proposerAddress = crypto.PubkeyToAddress(cfg.L1ProposerPrivKey.PublicKey)
	p.ctx = ctx
	p.Config = cfg
	p.lastProposedAt = time.Now()

	// RPC clients
	if p.rpc, err = rpc.NewClient(p.ctx, cfg.ClientConfig); err != nil {
		return fmt.Errorf("initialize rpc clients error: %w", err)
	}

	// Protocol configs
	protocolConfigs, err := p.rpc.TaikoL1.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}
	p.protocolConfigs = &protocolConfigs

	log.Info("Protocol configs", "configs", p.protocolConfigs)

	if p.tiers, err = p.rpc.GetTiers(ctx); err != nil {
		return err
	}
	if err := p.initTierFees(); err != nil {
		return err
	}

	if p.txmgr, err = txmgr.NewSimpleTxManager(
		"proposer",
		log.Root(),
		&metrics.TxMgrMetrics,
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	if p.proverSelector, err = selector.NewETHFeeEOASelector(
		&protocolConfigs,
		p.rpc,
		p.proposerAddress,
		cfg.TaikoL1Address,
		cfg.AssignmentHookAddress,
		p.tierFees,
		cfg.TierFeePriceBump,
		cfg.ProverEndpoints,
		cfg.MaxTierFeePriceBumps,
		proverAssignmentTimeout,
		requestProverServerTimeout,
	); err != nil {
		return err
	}

	if cfg.BlobAllowed {
		p.txBuilder = builder.NewBlobTransactionBuilder(
			p.rpc,
			p.L1ProposerPrivKey,
			p.proverSelector,
			p.Config.L1BlockBuilderTip,
			cfg.TaikoL1Address,
			cfg.L2SuggestedFeeRecipient,
			cfg.AssignmentHookAddress,
			cfg.ProposeBlockTxGasLimit,
			cfg.ExtraData,
		)
	} else {
		p.txBuilder = builder.NewCalldataTransactionBuilder(
			p.rpc,
			p.L1ProposerPrivKey,
			p.proverSelector,
			p.Config.L1BlockBuilderTip,
			cfg.L2SuggestedFeeRecipient,
			cfg.TaikoL1Address,
			cfg.AssignmentHookAddress,
			cfg.ProposeBlockTxGasLimit,
			cfg.ExtraData,
		)
	}

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
func (p *Proposer) fetchPoolContent(filterPoolContent bool) ([]types.Transactions, error) {
	// Fetch the pool content.
	preBuiltTxList, err := p.rpc.GetPoolContent(
		p.ctx,
		p.proposerAddress,
		p.protocolConfigs.BlockMaxGasLimit,
		rpc.BlockMaxTxListBytes,
		p.LocalAddresses,
		p.MaxProposedTxListsPerEpoch,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch transaction pool content: %w", err)
	}

	txLists := []types.Transactions{}
	for i, txs := range preBuiltTxList {
		// Filter the pool content if the filterPoolContent flag is set.
		if txs.EstimatedGasUsed < p.MinGasUsed && txs.BytesLength < p.MinTxListBytes && filterPoolContent {
			log.Info(
				"Pool content skipped",
				"index", i,
				"estimatedGasUsed", txs.EstimatedGasUsed,
				"minGasUsed", p.MinGasUsed,
				"bytesLength", txs.BytesLength,
				"minBytesLength", p.MinTxListBytes,
			)
			break
		}
		txLists = append(txLists, txs.TxList)
	}
	// If the pool content is empty and the checkPoolContent flag is not set, return an empty list.
	if !filterPoolContent && len(txLists) == 0 {
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

	log.Info("Transactions lists count", "count", len(txLists))

	return txLists, nil
}

// ProposeOp performs a proposing operation, fetching transactions
// from L2 execution engine's tx pool, splitting them by proposing constraints,
// and then proposing them to TaikoL1 contract.
func (p *Proposer) ProposeOp(ctx context.Context) error {
	var (
		chainID = new(big.Int).SetUint64(167000)
		to      = common.HexToAddress("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045") // vitalk.eth
		sender  = p.proposerAddress
		txLists []types.Transactions
	)
	nonce, err := p.rpc.L2.NonceAt(ctx, sender, nil)
	if err != nil {
		return err
	}

	log.Info("Nonce", "nonce", nonce)

	transaction := &types.DynamicFeeTx{
		ChainID:   chainID,
		Nonce:     nonce,
		To:        &to,
		GasTipCap: new(big.Int).SetUint64(2_000_000_000),
		GasFeeCap: new(big.Int).SetUint64(4_000_000_000),
		Gas:       150_000,
		Value:     new(big.Int).SetUint64(params.Ether / 10),
		Data:      common.FromHex("0x0a5461696b6f207265636f676e697a657320746865207069766f74616c20636f6e747269627574696f6e73206f662074686520666f6c6c6f77696e6720696e646976696475616c733a0a416c6578616e6465722044652056696c6c696572732c20416d79205275696a6961204b652c2042656e746f6e2057616e2c204265726e617420476172636572616e2c20427265636874204465766f732c204279726f6e2057696562652c20436169205765692044617669642c2044616e69656c204b65737a65792c204461766964204d69727a616465682c2064316f6e79733175732c20456c697a6176657461204d696e616576612c2045696e6172205261736d757373656e2c20466c6f7269616e20477265696e65722c2047656f7267696f7320476b69747361732c2047756f20597520476176696e2c204a616e652042697a7a6f6e692c204a6176696572204672616e636973636f2c204a6566666572792057616c73682c204a6f7272696e204272756e732c204a6f617175696e204d656e6465732c204a6f6e617468616e2044616e69656c204368616e2c204b6172696d20546168612c204b656e6e657468204261737369672c204b68616c6564204b6164616c2c204b6f7262696e69616e204b61736265726765722c204b727a79737a746f662050616c6967612c204c692057656e204c75204c6f72612c204c696d204b656e672048696e2c204c696e205869616e6c696e672c204c6975204875616e2c204c6975205368616e676c69616e6720416c65782c204d616d792052617473696d62617a6166792c204d61726375732057656e747a2c204d6172696f20426172626172612c204d6174746865772046696e6573746f6e652c204d65766c616e612047656d6963692c204d696b6b6f204d61726b757320496b6f6c612c204d6f68616d616420456c204c617a2c204f6c656b73696920416c656b7365692c2050617472796b2042657a612c2050657461722056756a6f7669632c2050696572676961636f6d6f2050616c6d6973616e692c2051696e2059692c20526f676572204c616d2c2053616e697961204d6f72652c20536861646162204b68616e2c20546572656e6365204c616d2c20756d6564652e6574682c20566963746f72204c6f70657a2c2056696e63656e742052616d7365792c2057616e67205975652c205775204c6966752c2058752053687561692c2059616e686f6e67204c696e205279616e2c205a68616e6720596978696e6720436563696c69612c205a686f6e67204b6f6e676c69616e672c20616e64206f74686572732077686f207769736820746f2072656d61696e20616e6f6e796d6f75732e0a0a0a5461696b6fe789b9e6ada4e887b4e8b0a2e4bba5e4b88be4b8aae4babae5afb9e9a1b9e79baee79a84e69db0e587bae8b4a1e78caeefbc9a0ae894a1e4bc9fe38081e78e8be78ea5e38081e5be90e5b885e38081e8a683e687bfe38081e69fafe7919ee59889e38081e58898e6aca2e38081e4bd99e69e9ce38081e9929fe5ad94e4baaee38081e590b4e58a9be5af8ce38081e69e97e58588e78eb2e38081e58898e5b09ae4baaee38081416c6578616e6465722044652056696c6c69657273e3808142656e746f6e2057616ee380814265726e617420476172636572616ee38081427265636874204465766f73e380814279726f6e205769656265e3808144616e69656c204b65737a6579e380814461766964204d69727a61646568e3808164316f6e7973317573e38081456c697a6176657461204d696e61657661e3808145696e6172205261736d757373656ee38081466c6f7269616e20477265696e6572e3808147656f7267696f7320476b6974736173e380814a616e652042697a7a6f6e69e380814a6176696572204672616e636973636fe380814a6566666572792057616c7368e380814a6f7272696e204272756e73e380814a6f617175696e204d656e646573e380814a6f6e617468616e2044616e69656c204368616ee380814b6172696d2054616861e380814b656e6e65746820426173736967e380814b68616c6564204b6164616ce380814b6f7262696e69616e204b6173626572676572e380814b727a79737a746f662050616c696761e380814c692057656e204c75204c6f7261e380814c696d204b656e672048696ee380814d616d792052617473696d62617a616679e380814d61726375732057656e747ae380814d6172696f2042617262617261e380814d6174746865772046696e6573746f6e65e380814d65766c616e612047656d696369e380814d696b6b6f204d61726b757320496b6f6c61e380814d6f68616d616420456c204c617ae380814f6c656b73696920416c656b736569e3808150617472796b2042657a61e3808150657461722056756a6f766963e3808150696572676961636f6d6f2050616c6d6973616e69e38081526f676572204c616de3808153616e697961204d6f7265e38081536861646162204b68616ee38081546572656e6365204c616de38081756d6564652e657468e38081566963746f72204c6f70657ae3808156696e63656e742052616d736579e3808159616e686f6e67204c696e205279616ee380815a68616e6720596978696e6720436563696c6961efbc8ce4bba5e58f8ae585b6e4bb96e5b88ce69c9be4bf9de68c81e58cbfe5908de79a84e4babae5a3abe380820a0a0a"),
	}

	signedTransaction, err := types.SignTx(
		types.NewTx(transaction),
		types.LatestSignerForChainID(chainID),
		p.L1ProposerPrivKey,
	)
	if err != nil {
		return err
	}

	txLists = append(txLists, types.Transactions{signedTransaction})

	// If the pool content is empty, return.
	if len(txLists) == 0 {
		return nil
	}

	g, gCtx := errgroup.WithContext(ctx)
	// Propose all L2 transactions lists.
	for _, txs := range txLists[:utils.Min(p.MaxProposedTxListsPerEpoch, uint64(len(txLists)))] {
		nonce, err := p.rpc.L1.PendingNonceAt(ctx, p.proposerAddress)
		if err != nil {
			log.Error("Failed to get proposer nonce", "error", err)
			break
		}

		log.Info("Proposer current pending nonce", "nonce", nonce)

		g.Go(func() error {
			txListBytes, err := rlp.EncodeToBytes(txs)
			if err != nil {
				return fmt.Errorf("failed to encode transactions: %w", err)
			}
			if err := p.ProposeTxList(gCtx, txListBytes, uint(txs.Len())); err != nil {
				return err
			}
			p.lastProposedAt = time.Now()
			return nil
		})

		if err := p.rpc.WaitL1NewPendingTransaction(ctx, p.proposerAddress, nonce); err != nil {
			log.Error("Failed to wait for new pending transaction", "error", err)
		}
	}
	if err := g.Wait(); err != nil {
		return err
	}

	return nil
}

// ProposeTxList proposes the given transactions list to TaikoL1 smart contract.
func (p *Proposer) ProposeTxList(
	ctx context.Context,
	txListBytes []byte,
	txNum uint,
) error {
	compressedTxListBytes, err := utils.Compress(txListBytes)
	if err != nil {
		return err
	}

	txCandidate, err := p.txBuilder.Build(
		ctx,
		p.tierFees,
		p.IncludeParentMetaHash,
		compressedTxListBytes,
	)
	if err != nil {
		log.Warn("Failed to build TaikoL1.proposeBlock transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	receipt, err := p.txmgr.Send(ctx, *txCandidate)
	if err != nil {
		log.Warn("Failed to send TaikoL1.proposeBlock transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to propose block: %s", receipt.TxHash.Hex())
	}

	log.Info("📝 Propose transactions succeeded", "txs", txNum)

	metrics.ProposerProposedTxListsCounter.Add(1)
	metrics.ProposerProposedTxsCounter.Add(float64(txNum))

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

// Name returns the application name.
func (p *Proposer) Name() string {
	return "proposer"
}

// initTierFees initializes the proving fees for every proof tier configured in the protocol for the proposer.
func (p *Proposer) initTierFees() error {
	for _, tier := range p.tiers {
		log.Info(
			"Protocol tier",
			"id", tier.ID,
			"name", string(bytes.TrimRight(tier.VerifierName[:], "\x00")),
			"validityBond", utils.WeiToEther(tier.ValidityBond),
			"contestBond", utils.WeiToEther(tier.ContestBond),
			"provingWindow", tier.ProvingWindow,
			"cooldownWindow", tier.CooldownWindow,
		)

		switch tier.ID {
		case encoding.TierOptimisticID:
			p.tierFees = append(p.tierFees, encoding.TierFee{Tier: tier.ID, Fee: p.OptimisticTierFee})
		case encoding.TierSgxID:
			p.tierFees = append(p.tierFees, encoding.TierFee{Tier: tier.ID, Fee: p.SgxTierFee})
		case encoding.TierGuardianMinorityID:
			p.tierFees = append(p.tierFees, encoding.TierFee{Tier: tier.ID, Fee: common.Big0})
		case encoding.TierGuardianMajorityID:
			// Guardian prover should not charge any fee.
			p.tierFees = append(p.tierFees, encoding.TierFee{Tier: tier.ID, Fee: common.Big0})
		default:
			return fmt.Errorf("unknown tier: %d", tier.ID)
		}
	}

	return nil
}
