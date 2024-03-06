package prover

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/ethereum/go-ethereum/ethdb/leveldb"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/version"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	guardianproversender "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/guardian_prover_sender"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/server"
)

var (
	errTierNotFound   = errors.New("tier not found")
	heartbeatInterval = 12 * time.Second
)

// Prover keeps trying to prove newly proposed blocks.
type Prover struct {
	// Configurations
	cfg              *Config
	proverAddress    common.Address
	proverPrivateKey *ecdsa.PrivateKey

	// Clients
	rpc *rpc.Client

	// Guardian prover related
	srv                  *server.ProverServer
	guardianProverSender guardianproversender.BlockSenderHeartbeater

	// Contract configurations
	protocolConfigs *bindings.TaikoDataConfig

	// States
	lastHandledBlockID uint64
	genesisHeightL1    uint64
	l1Current          *types.Header
	reorgDetectedFlag  bool
	tiers              []*rpc.TierProviderTierWithID

	// Proof submitters
	proofSubmitters []proofSubmitter.Submitter
	proofContester  proofSubmitter.Contester

	proofWindowExpiredCh chan *bindings.TaikoL1ClientBlockProposed
	proveNotify          chan struct{}

	// Proof related
	proofGenerationCh chan *proofProducer.ProofWithHeader

	// Concurrency guards
	proposeConcurrencyGuard     chan struct{}
	submitProofConcurrencyGuard chan struct{}

	ctx context.Context
	wg  sync.WaitGroup
}

// InitFromCli initializes the given prover instance based on the command line flags.
func (p *Prover) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, p, cfg)
}

// InitFromConfig initializes the prover instance based on the given configurations.
func InitFromConfig(ctx context.Context, p *Prover, cfg *Config) (err error) {
	p.cfg = cfg
	p.ctx = ctx
	p.proverPrivateKey = cfg.L1ProverPrivKey

	// Clients
	if p.rpc, err = rpc.NewClient(p.ctx, &rpc.ClientConfig{
		L1Endpoint:            cfg.L1WsEndpoint,
		L2Endpoint:            cfg.L2WsEndpoint,
		TaikoL1Address:        cfg.TaikoL1Address,
		TaikoL2Address:        cfg.TaikoL2Address,
		TaikoTokenAddress:     cfg.TaikoTokenAddress,
		GuardianProverAddress: cfg.GuardianProverAddress,
		Timeout:               cfg.RPCTimeout,
	}); err != nil {
		return err
	}

	// Configs
	protocolConfigs, err := p.rpc.TaikoL1.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}
	p.protocolConfigs = &protocolConfigs

	log.Info("Protocol configs", "configs", p.protocolConfigs)

	p.proverAddress = crypto.PubkeyToAddress(p.cfg.L1ProverPrivKey.PublicKey)

	chBufferSize := p.protocolConfigs.BlockMaxProposals
	p.proofGenerationCh = make(chan *proofProducer.ProofWithHeader, chBufferSize)
	p.proofWindowExpiredCh = make(chan *bindings.TaikoL1ClientBlockProposed, chBufferSize)
	p.proveNotify = make(chan struct{}, 1)

	if err := p.initL1Current(cfg.StartingBlockID); err != nil {
		return fmt.Errorf("initialize L1 current cursor error: %w", err)
	}

	// Concurrency guards
	p.proposeConcurrencyGuard = make(chan struct{}, cfg.Capacity)
	p.submitProofConcurrencyGuard = make(chan struct{}, cfg.Capacity)

	// Protocol proof tiers
	if p.tiers, err = p.rpc.GetTiers(ctx); err != nil {
		return err
	}

	// Proof submitters
	for _, tier := range p.tiers {
		var (
			producer  proofProducer.ProofProducer
			submitter proofSubmitter.Submitter
		)
		switch tier.ID {
		case encoding.TierOptimisticID:
			producer = &proofProducer.OptimisticProofProducer{DummyProofProducer: new(proofProducer.DummyProofProducer)}
		case encoding.TierSgxID:
			sgxProducer, err := proofProducer.NewSGXProducer(
				cfg.RaikoHostEndpoint,
				cfg.L1HttpEndpoint,
				cfg.L1BeaconEndpoint,
				cfg.L2HttpEndpoint,
			)
			if err != nil {
				return err
			}
			if p.cfg.Dummy {
				sgxProducer.DummyProofProducer = new(proofProducer.DummyProofProducer)
			}
			producer = sgxProducer
		case encoding.TierGuardianID:
			producer = proofProducer.NewGuardianProofProducer(p.cfg.EnableLivenessBondProof)
		}

		if submitter, err = proofSubmitter.New(
			p.rpc,
			producer,
			p.proofGenerationCh,
			p.cfg.TaikoL2Address,
			p.cfg.L1ProverPrivKey,
			p.cfg.Graffiti,
			p.cfg.ProofSubmissionMaxRetry,
			p.cfg.BackOffRetryInterval,
			p.cfg.WaitReceiptTimeout,
			p.cfg.ProveBlockGasLimit,
			p.cfg.ProveBlockTxReplacementMultiplier,
			p.cfg.ProveBlockMaxTxGasTipCap,
		); err != nil {
			return err
		}

		p.proofSubmitters = append(p.proofSubmitters, submitter)
	}

	// Proof contester
	p.proofContester, err = proofSubmitter.NewProofContester(
		p.rpc,
		p.cfg.L1ProverPrivKey,
		p.cfg.ProveBlockGasLimit,
		p.cfg.ProveBlockTxReplacementMultiplier,
		p.cfg.ProveBlockMaxTxGasTipCap,
		p.cfg.ProofSubmissionMaxRetry,
		p.cfg.BackOffRetryInterval,
		p.cfg.WaitReceiptTimeout,
		p.cfg.Graffiti,
	)
	if err != nil {
		return err
	}

	// levelDB
	var db ethdb.KeyValueStore
	if cfg.DatabasePath != "" {
		if db, err = leveldb.New(
			cfg.DatabasePath,
			int(cfg.DatabaseCacheSize),
			16, // Minimum number of files handles is 16 in leveldb.
			"taiko",
			false,
		); err != nil {
			return err
		}
	}

	// Prover server
	proverServerOpts := &server.NewProverServerOpts{
		ProverPrivateKey:        p.cfg.L1ProverPrivKey,
		MinOptimisticTierFee:    p.cfg.MinOptimisticTierFee,
		MinSgxTierFee:           p.cfg.MinSgxTierFee,
		MaxExpiry:               p.cfg.MaxExpiry,
		MaxBlockSlippage:        p.cfg.MaxBlockSlippage,
		TaikoL1Address:          p.cfg.TaikoL1Address,
		AssignmentHookAddress:   p.cfg.AssignmentHookAddress,
		ProposeConcurrencyGuard: p.proposeConcurrencyGuard,
		RPC:                     p.rpc,
		ProtocolConfigs:         &protocolConfigs,
		LivenessBond:            protocolConfigs.LivenessBond,
		IsGuardian:              p.IsGuardianProver(),
		DB:                      db,
	}
	if p.srv, err = server.New(proverServerOpts); err != nil {
		return err
	}

	// Guardian prover heartbeat sender
	if p.IsGuardianProver() {
		// Check guardian prover contract address is correct.
		if _, err := p.rpc.GuardianProver.MinGuardians(&bind.CallOpts{Context: ctx}); err != nil {
			return fmt.Errorf("failed to get MinGuardians from guardian prover contract: %w", err)
		}

		p.guardianProverSender = guardianproversender.New(
			p.cfg.L1ProverPrivKey,
			p.cfg.GuardianProverHealthCheckServerEndpoint,
			db,
			p.rpc,
			p.proverAddress,
		)
	}

	return nil
}

// setApprovalAmount will set the allowance on the TaikoToken contract for the
// configured proverAddress as owner and the contract as spender,
// if `--prover.allowance` flag is provided for allowance.
func (p *Prover) setApprovalAmount(ctx context.Context, contract common.Address) error {
	if p.cfg.Allowance == nil || p.cfg.Allowance.Cmp(common.Big0) != 1 {
		log.Info("Skipping setting approval, `--prover.allowance` flag not set")
		return nil
	}

	allowance, err := p.rpc.TaikoToken.Allowance(
		&bind.CallOpts{Context: ctx},
		p.proverAddress,
		contract,
	)
	if err != nil {
		return err
	}

	log.Info("Existing allowance for the contract", "allowance", allowance.String(), "contract", contract)

	if allowance.Cmp(p.cfg.Allowance) >= 0 {
		log.Info(
			"Skipping setting allowance, allowance already greater or equal",
			"allowance", allowance.String(),
			"approvalAmount", p.cfg.Allowance.String(),
			"contract", contract,
		)
		return nil
	}

	opts, err := bind.NewKeyedTransactorWithChainID(
		p.cfg.L1ProverPrivKey,
		p.rpc.L1.ChainID,
	)
	if err != nil {
		return err
	}
	opts.Context = ctx

	log.Info("Approving the contract for taiko token", "allowance", p.cfg.Allowance.String(), "contract", contract)

	tx, err := p.rpc.TaikoToken.Approve(
		opts,
		contract,
		p.cfg.Allowance,
	)
	if err != nil {
		return err
	}

	receipt, err := rpc.WaitReceipt(ctx, p.rpc.L1, tx)
	if err != nil {
		return err
	}

	log.Info(
		"Approved the contract for taiko token",
		"txHash", receipt.TxHash.Hex(),
		"contract", contract,
	)

	if allowance, err = p.rpc.TaikoToken.Allowance(
		&bind.CallOpts{Context: ctx},
		p.proverAddress,
		contract,
	); err != nil {
		return err
	}

	log.Info("New allowance for the contract", "allowance", allowance.String(), "contract", contract)

	return nil
}

// Start starts the main loop of the L2 block prover.
func (p *Prover) Start() error {
	for _, contract := range []common.Address{p.cfg.TaikoL1Address, p.cfg.AssignmentHookAddress} {
		if err := p.setApprovalAmount(p.ctx, contract); err != nil {
			log.Crit("Failed to set approval amount", "contract", contract, "error", err)
		}
	}

	go func() {
		if err := p.srv.Start(fmt.Sprintf(":%v", p.cfg.HTTPServerPort)); !errors.Is(err, http.ErrServerClosed) {
			log.Crit("Failed to start http server", "error", err)
		}
	}()

	if p.IsGuardianProver() {
		if err := p.guardianProverSender.SendStartup(
			p.ctx,
			version.CommitVersion(),
			version.CommitVersion(),
			p.cfg.L1NodeVersion,
			p.cfg.L2NodeVersion,
		); err != nil {
			log.Crit("Failed to send guardian prover startup", "error", err)
		}

		p.wg.Add(1)
		go p.heartbeatInterval(p.ctx)
	}

	p.wg.Add(1)
	go p.eventLoop()

	return nil
}

// eventLoop starts the main loop of Taiko prover.
func (p *Prover) eventLoop() {
	defer func() {
		p.wg.Done()
	}()

	// reqProving requests performing a proving operation, won't block
	// if we are already proving.
	reqProving := func() {
		select {
		case p.proveNotify <- struct{}{}:
		default:
		}
	}
	// Call reqProving() right away to catch up with the latest state.
	reqProving()

	// If there is too many (TaikoData.Config.blockMaxProposals) pending blocks in TaikoL1 contract, there will be no new
	// BlockProposed temporarily, so except the BlockProposed subscription, we need another trigger to start
	// fetching the proposed blocks.
	forceProvingTicker := time.NewTicker(15 * time.Second)
	defer forceProvingTicker.Stop()

	chBufferSize := p.protocolConfigs.BlockMaxProposals
	blockProposedCh := make(chan *bindings.TaikoL1ClientBlockProposed, chBufferSize)
	blockVerifiedCh := make(chan *bindings.TaikoL1ClientBlockVerified, chBufferSize)
	transitionProvedCh := make(chan *bindings.TaikoL1ClientTransitionProved, chBufferSize)
	transitionContestedCh := make(chan *bindings.TaikoL1ClientTransitionContested, chBufferSize)
	// Subscriptions
	blockProposedSub := rpc.SubscribeBlockProposed(p.rpc.TaikoL1, blockProposedCh)
	blockVerifiedSub := rpc.SubscribeBlockVerified(p.rpc.TaikoL1, blockVerifiedCh)
	transitionProvedSub := rpc.SubscribeTransitionProved(p.rpc.TaikoL1, transitionProvedCh)
	transitionContestedSub := rpc.SubscribeTransitionContested(p.rpc.TaikoL1, transitionContestedCh)
	defer func() {
		blockProposedSub.Unsubscribe()
		blockVerifiedSub.Unsubscribe()
		transitionProvedSub.Unsubscribe()
		transitionContestedSub.Unsubscribe()
	}()

	for {
		select {
		case <-p.ctx.Done():
			return
		case proofWithHeader := <-p.proofGenerationCh:
			p.submitProofOp(p.ctx, proofWithHeader)
		case <-p.proveNotify:
			if err := p.proveOp(); err != nil {
				log.Error("Prove new blocks error", "error", err)
			}
		case e := <-blockVerifiedCh:
			if err := p.onBlockVerified(p.ctx, e); err != nil {
				log.Error("Handle BlockVerified event error", "error", err)
			}
		case e := <-transitionProvedCh:
			if err := p.onTransitionProved(p.ctx, e); err != nil {
				log.Error("Handle TransitionProved event error", "error", err)
			}
		case e := <-transitionContestedCh:
			if err := p.onTransitionContested(p.ctx, e); err != nil {
				log.Error("Handle TransitionContested event error", "error", err)
			}
		case e := <-p.proofWindowExpiredCh:
			if err := p.onProvingWindowExpired(p.ctx, e); err != nil {
				log.Error("Handle provingWindow expired event error", "error", err)
			}
		case <-blockProposedCh:
			reqProving()
		case <-forceProvingTicker.C:
			reqProving()
		}
	}
}

// Close closes the prover instance.
func (p *Prover) Close(ctx context.Context) {
	if p.guardianProverSender != nil {
		if err := p.guardianProverSender.Close(); err != nil {
			log.Error("failed to close database connection", "error", err)
		}
	}

	if err := p.srv.Shutdown(ctx); err != nil {
		log.Error("Failed to shut down prover server", "error", err)
	}
	p.wg.Wait()
}

// proveOp iterates through BlockProposed events
func (p *Prover) proveOp() error {
	firstTry := true

	for firstTry || p.reorgDetectedFlag {
		p.reorgDetectedFlag = false
		firstTry = false

		iter, err := eventIterator.NewBlockProposedIterator(p.ctx, &eventIterator.BlockProposedIteratorConfig{
			Client:               p.rpc.L1,
			TaikoL1:              p.rpc.TaikoL1,
			StartHeight:          new(big.Int).SetUint64(p.l1Current.Number.Uint64()),
			OnBlockProposedEvent: p.onBlockProposed,
		})
		if err != nil {
			log.Error("Failed to start event iterator", "event", "BlockProposed", "error", err)
			return err
		}

		if err := iter.Iter(); err != nil {
			return err
		}
	}

	return nil
}

// onBlockProposed tries to prove that the newly proposed block is valid/invalid.
func (p *Prover) onBlockProposed(
	ctx context.Context,
	event *bindings.TaikoL1ClientBlockProposed,
	end eventIterator.EndBlockProposedEventIterFunc,
) error {
	// If we are operating as a guardian prover,
	// we should sign all seen proposed blocks as soon as possible.
	go func() {
		if !p.IsGuardianProver() {
			return
		}
		if err := p.guardianProverSender.SignAndSendBlock(ctx, event.BlockId); err != nil {
			log.Error("Guardian prover unable to sign block", "blockID", event.BlockId, "error", err)
		}
	}()

	// If there are newly generated proofs, we need to submit them as soon as possible.
	if len(p.proofGenerationCh) > 0 {
		log.Info("onBlockProposed early return", "proofGenerationChannelLength", len(p.proofGenerationCh))
		end()
		return nil
	}

	// Wait for the corresponding L2 block being mined.
	if _, err := p.rpc.WaitL1Origin(ctx, event.BlockId); err != nil {
		return fmt.Errorf("failed to wait L1Origin (eventID %d): %w", event.BlockId, err)
	}

	// Check whether the L2 EE's anchored L1 info, to see if the L1 chain has been reorged.
	reorged, l1CurrentToReset, lastHandledBlockIDToReset, err := p.rpc.CheckL1ReorgFromL2EE(
		ctx,
		new(big.Int).Sub(event.BlockId, common.Big1),
	)
	if err != nil {
		return fmt.Errorf("failed to check whether L1 chain was reorged from L2EE (eventID %d): %w", event.BlockId, err)
	}

	// Then check the l1Current cursor at first, to see if the L1 chain has been reorged.
	if !reorged {
		if reorged, l1CurrentToReset, lastHandledBlockIDToReset, err = p.rpc.CheckL1ReorgFromL1Cursor(
			ctx,
			p.l1Current,
			p.genesisHeightL1,
		); err != nil {
			return fmt.Errorf(
				"failed to check whether L1 chain was reorged from l1Current (eventID %d): %w",
				event.BlockId,
				err,
			)
		}
	}

	if reorged {
		log.Info(
			"Reset L1Current cursor due to reorg",
			"l1CurrentHeightOld", p.l1Current,
			"l1CurrentHeightNew", l1CurrentToReset.Number,
			"lastHandledBlockIDOld", p.lastHandledBlockID,
			"lastHandledBlockIDNew", lastHandledBlockIDToReset,
		)
		p.l1Current = l1CurrentToReset
		if lastHandledBlockIDToReset == nil {
			p.lastHandledBlockID = 0
		} else {
			p.lastHandledBlockID = lastHandledBlockIDToReset.Uint64()
		}
		p.reorgDetectedFlag = true
		end()
		return nil
	}

	if event.BlockId.Uint64() <= p.lastHandledBlockID {
		return nil
	}

	lastL1OriginHeader, err := p.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(event.Meta.L1Height))
	if err != nil {
		return fmt.Errorf("failed to get L1 header, height %d: %w", event.Meta.L1Height, err)
	}

	if lastL1OriginHeader.Hash() != event.Meta.L1Hash {
		log.Warn(
			"L1 block hash mismatch due to L1 reorg",
			"height", event.Meta.L1Height,
			"lastL1OriginHeader", lastL1OriginHeader.Hash(),
			"l1HashInEvent", event.Meta.L1Hash,
		)

		return fmt.Errorf(
			"L1 block hash mismatch due to L1 reorg: %s != %s",
			lastL1OriginHeader.Hash(),
			event.Meta.L1Hash,
		)
	}

	log.Info(
		"Proposed block",
		"l1Height", event.Raw.BlockNumber,
		"l1Hash", event.Raw.BlockHash,
		"blockID", event.BlockId,
		"removed", event.Raw.Removed,
		"assignedProver", event.AssignedProver,
		"livenessBond", event.LivenessBond,
		"minTier", event.Meta.MinTier,
	)
	metrics.ProverReceivedProposedBlockGauge.Update(event.BlockId.Int64())

	// Move l1Current cursor.
	newL1Current, err := p.rpc.L1.HeaderByHash(ctx, event.Raw.BlockHash)
	if err != nil {
		return err
	}
	p.l1Current = newL1Current
	p.lastHandledBlockID = event.BlockId.Uint64()

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				p.proposeConcurrencyGuard <- struct{}{}
				defer func() { <-p.proposeConcurrencyGuard }()

				if err := p.handleNewBlockProposedEvent(ctx, event); err != nil {
					log.Error(
						"Failed to handle BlockProposed event",
						"error", err,
						"blockID", event.BlockId,
						"minTier", event.Meta.MinTier,
						"maxRetrys", p.cfg.BackOffMaxRetrys,
					)
					return err
				}
				return nil
			},
			backoff.WithMaxRetries(backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval), p.cfg.BackOffMaxRetrys),
		); err != nil {
			log.Error("Handle new BlockProposed event error", "error", err)
		}
	}()

	return nil
}

// handleNewBlockProposedEvent handles the new block proposed event.
func (p *Prover) handleNewBlockProposedEvent(ctx context.Context, e *bindings.TaikoL1ClientBlockProposed) error {
	// Check whether the block has been verified.
	isVerified, err := p.isBlockVerified(e.BlockId)
	if err != nil {
		return fmt.Errorf("failed to check if the current L2 block is verified: %w", err)
	}
	if isVerified {
		log.Info("📋 Block has been verified", "blockID", e.BlockId)
		return nil
	}

	// Check whether the block's proof is still needed.
	proofStatus, err := rpc.GetBlockProofStatus(
		p.ctx,
		p.rpc,
		e.BlockId,
		p.proverAddress,
	)
	if err != nil {
		return fmt.Errorf("failed to check whether the L2 block needs a new proof: %w", err)
	}

	if proofStatus.IsSubmitted {
		// If there is already a proof submitted and there is no need to contest
		// it, we skip proving this block here.
		if !proofStatus.Invalid {
			log.Info(
				"A valid proof has been submitted, skip proving",
				"blockID", e.BlockId,
				"parent", proofStatus.ParentHeader.Hash(),
			)
			return nil
		}

		// If there is an invalid proof, but current prover is not in contest mode, we skip proving this block.
		if !p.cfg.ContesterMode {
			log.Info(
				"An invalid proof has been submitted, but current prover is not in contest mode, skip proving",
				"blockID", e.BlockId,
				"parent", proofStatus.ParentHeader.Hash(),
			)
			return nil
		}

		// The proof submitted to protocol is invalid.
		return p.handleInvalidProof(
			ctx,
			e.BlockId,
			new(big.Int).SetUint64(e.Raw.BlockNumber),
			proofStatus.ParentHeader.Hash(),
			proofStatus.CurrentTransitionState.Contester,
			&e.Meta,
			proofStatus.CurrentTransitionState.Tier,
		)
	}

	provingWindow, err := p.getProvingWindow(e)
	if err != nil {
		return fmt.Errorf("failed to get proving window: %w", err)
	}

	var (
		now                    = uint64(time.Now().Unix())
		provingWindowExpiresAt = e.Meta.Timestamp + uint64(provingWindow.Seconds())
		provingWindowExpired   = now > provingWindowExpiresAt
		timeToExpire           = time.Duration(provingWindowExpiresAt-now) * time.Second
	)
	if provingWindowExpired {
		// If the proving window is expired, we need to check if the current prover is the assigned prover
		// at first, if yes, we should skip proving this block, if no, then we check if the current prover
		// wants to prove unassigned blocks.
		log.Info(
			"Proposed block's proving window has expired",
			"blockID", e.BlockId,
			"prover", e.AssignedProver,
			"now", now,
			"expiresAt", provingWindowExpiresAt,
			"minTier", e.Meta.MinTier,
		)
		if e.AssignedProver == p.proverAddress {
			log.Warn(
				"Assigned prover is the current prover, but the proving window has expired, skip proving",
				"blockID", e.BlockId,
				"prover", e.AssignedProver,
				"expiresAt", provingWindowExpiresAt,
			)
			return nil
		}
		if !p.cfg.ProveUnassignedBlocks {
			log.Info(
				"Skip proving expired blocks",
				"blockID", e.BlockId,
				"prover", e.AssignedProver,
				"expiresAt", provingWindowExpiresAt,
			)
			return nil
		}
	} else {
		// If the proving window is not expired, we need to check if the current prover is the assigned prover,
		// if no and the current prover wants to prove unassigned blocks, then we should wait for its expiration.
		if e.AssignedProver != p.proverAddress {
			log.Info(
				"Proposed block is not provable",
				"blockID", e.BlockId,
				"prover", e.AssignedProver,
				"expiresAt", provingWindowExpiresAt,
				"timeToExpire", timeToExpire,
			)

			if p.cfg.ProveUnassignedBlocks {
				log.Info(
					"Add proposed block to wait for proof window expiration",
					"blockID", e.BlockId,
				)
				time.AfterFunc(
					// Add another 60 seconds, to ensure one more L1 block will be mined before the proof submission
					timeToExpire+60*time.Second,
					func() { p.proofWindowExpiredCh <- e },
				)
			}

			return nil
		}
	}

	tier := e.Meta.MinTier
	if p.IsGuardianProver() {
		tier = encoding.TierGuardianID
	}

	log.Info(
		"Proposed block is provable",
		"blockID", e.BlockId,
		"prover", e.AssignedProver,
		"expiresAt", provingWindowExpiresAt,
		"minTier", e.Meta.MinTier,
		"currentTier", tier,
	)

	metrics.ProverProofsAssigned.Inc(1)

	if proofSubmitter := p.selectSubmitter(tier); proofSubmitter != nil {
		return proofSubmitter.RequestProof(ctx, e)
	}

	return nil
}

// handleInvalidProof handles the case when the proof submitted to protocol is invalid.
func (p *Prover) handleInvalidProof(
	ctx context.Context,
	blockID *big.Int,
	proposedIn *big.Int,
	parentHash common.Hash,
	contester common.Address,
	meta *bindings.TaikoDataBlockMetadata,
	tier uint16,
) error {
	// The proof submitted to protocol is invalid.
	log.Info(
		"Invalid proof detected",
		"blockID", blockID,
		"parent", parentHash,
	)

	// If there is no contester, we submit a contest to protocol.
	if contester == rpc.ZeroAddress {
		log.Info(
			"Try submitting a contest",
			"blockID", blockID,
			"parent", parentHash,
		)

		return p.proofContester.SubmitContest(ctx, blockID, proposedIn, parentHash, meta, tier)
	}

	log.Info(
		"Try submitting a higher tier proof",
		"blockID", blockID,
		"parent", parentHash,
	)

	// If there is already a contester, we try submitting a proof with a higher tier here.
	return p.requestProofByBlockID(blockID, proposedIn, tier+1, nil)
}

// submitProofOp performs a proof submission operation.
func (p *Prover) submitProofOp(ctx context.Context, proofWithHeader *proofProducer.ProofWithHeader) {
	go func() {
		p.submitProofConcurrencyGuard <- struct{}{}

		defer func() {
			<-p.submitProofConcurrencyGuard
		}()

		if err := backoff.Retry(
			func() error {
				proofSubmitter := p.getSubmitterByTier(proofWithHeader.Tier)
				if proofSubmitter == nil {
					return nil
				}

				if err := proofSubmitter.SubmitProof(p.ctx, proofWithHeader); err != nil {
					log.Error("Submit proof error", "error", err)
					return err
				}

				return nil
			},
			backoff.WithMaxRetries(backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval), p.cfg.BackOffMaxRetrys),
		); err != nil {
			log.Error("Submit proof error", "error", err)
		}
	}()
}

// onTransitionContested tries to submit a higher tier proof for the contested transition.
func (p *Prover) onTransitionContested(ctx context.Context, e *bindings.TaikoL1ClientTransitionContested) error {
	log.Info(
		"🗡 Transition contested",
		"blockID", e.BlockId,
		"parentHash", common.Bytes2Hex(e.Tran.ParentHash[:]),
		"hash", common.Bytes2Hex(e.Tran.BlockHash[:]),
		"stateRoot", common.BytesToHash(e.Tran.StateRoot[:]),
		"contester", e.Contester,
		"bond", e.ContestBond,
	)

	// If this prover is not in contester mode, we simply output a log and return.
	if !p.cfg.ContesterMode {
		return nil
	}

	contestedTransition, err := p.rpc.TaikoL1.GetTransition(
		&bind.CallOpts{Context: ctx},
		e.BlockId.Uint64(),
		e.Tran.ParentHash,
	)
	if err != nil {
		return err
	}

	// Compare the contested transition to the block in local L2 canonical chain.
	isValidProof, err := p.isValidProof(
		ctx,
		e.BlockId,
		e.Tran.ParentHash,
		contestedTransition.BlockHash,
		contestedTransition.StateRoot,
	)
	if err != nil {
		return err
	}
	if isValidProof {
		log.Info(
			"Contested transition is valid to local canonical chain, ignore the contest",
			"blockID", e.BlockId,
			"parentHash", common.Bytes2Hex(e.Tran.ParentHash[:]),
			"hash", common.Bytes2Hex(contestedTransition.BlockHash[:]),
			"stateRoot", common.BytesToHash(contestedTransition.StateRoot[:]),
			"contester", e.Contester,
			"bond", e.ContestBond,
		)
		return nil
	}

	blockInfo, err := p.rpc.TaikoL1.GetBlock(&bind.CallOpts{Context: ctx}, e.BlockId.Uint64())
	if err != nil {
		return err
	}

	return p.requestProofByBlockID(e.BlockId, new(big.Int).SetUint64(blockInfo.Blk.ProposedIn), e.Tier+1, nil)
}

// onBlockVerified update the latestVerified block in current state, and cancels
// the block being proven if it's verified.
func (p *Prover) onBlockVerified(_ context.Context, e *bindings.TaikoL1ClientBlockVerified) error {
	metrics.ProverLatestVerifiedIDGauge.Update(e.BlockId.Int64())

	log.Info(
		"New verified block",
		"blockID", e.BlockId,
		"hash", common.BytesToHash(e.BlockHash[:]),
		"stateRoot", common.BytesToHash(e.StateRoot[:]),
		"assignedProver", e.AssignedProver,
		"prover", e.Prover,
	)

	return nil
}

// onTransitionProved verifies the proven block hash and will try contesting it if the block hash is wrong.
func (p *Prover) onTransitionProved(ctx context.Context, event *bindings.TaikoL1ClientTransitionProved) error {
	metrics.ProverReceivedProvenBlockGauge.Update(event.BlockId.Int64())

	// If the proof generation is cancellable, cancel it and release the capacity.
	proofSubmitter := p.getSubmitterByTier(event.Tier)
	if proofSubmitter != nil && proofSubmitter.Producer().Cancellable() {
		if err := proofSubmitter.Producer().Cancel(ctx, event.BlockId); err != nil {
			return err
		}
	}

	// If this prover is in contest mode, we check the validity of this proof and if it's invalid,
	// contest it with a higher tier proof.
	if !p.cfg.ContesterMode {
		return nil
	}

	isValidProof, err := p.isValidProof(
		ctx,
		event.BlockId,
		event.Tran.ParentHash,
		event.Tran.BlockHash,
		event.Tran.StateRoot,
	)
	if err != nil {
		return err
	}
	if isValidProof {
		return nil
	}

	blockInfo, err := p.rpc.TaikoL1.GetBlock(&bind.CallOpts{Context: ctx}, event.BlockId.Uint64())
	if err != nil {
		return err
	}

	log.Info(
		"Contest a proven transition",
		"blockID", event.BlockId,
		"l1Height", blockInfo.Blk.ProposedIn,
		"tier", event.Tier,
		"parentHash", common.Bytes2Hex(event.Tran.ParentHash[:]),
		"blockHash", common.Bytes2Hex(event.Tran.BlockHash[:]),
		"stateRoot", common.Bytes2Hex(event.Tran.StateRoot[:]),
	)

	return p.requestProofByBlockID(event.BlockId, new(big.Int).SetUint64(blockInfo.Blk.ProposedIn), event.Tier, event)
}

// Name returns the application name.
func (p *Prover) Name() string {
	return "prover"
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBlockID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	stateVars, err := p.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return err
	}
	p.genesisHeightL1 = stateVars.A.GenesisHeight

	if startingBlockID == nil {
		if stateVars.B.LastVerifiedBlockId == 0 {
			genesisL1Header, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(stateVars.A.GenesisHeight))
			if err != nil {
				return err
			}

			p.l1Current = genesisL1Header
			return nil
		}

		startingBlockID = new(big.Int).SetUint64(stateVars.B.LastVerifiedBlockId)
	}

	log.Info("Init L1Current cursor", "startingBlockID", startingBlockID)

	latestVerifiedHeaderL1Origin, err := p.rpc.L2.L1OriginByID(p.ctx, startingBlockID)
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			log.Warn("Failed to find L1Origin for blockID, use latest L1 head instead", "blockID", startingBlockID)
			l1Head, err := p.rpc.L1.HeaderByNumber(p.ctx, nil)
			if err != nil {
				return err
			}

			p.l1Current = l1Head
			return nil
		}
		return err
	}

	if p.l1Current, err = p.rpc.L1.HeaderByHash(p.ctx, latestVerifiedHeaderL1Origin.L1BlockHash); err != nil {
		return err
	}

	return nil
}

// isBlockVerified checks whether the given L2 block has been verified.
func (p *Prover) isBlockVerified(id *big.Int) (bool, error) {
	stateVars, err := p.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return false, err
	}

	return id.Uint64() <= stateVars.B.LastVerifiedBlockId, nil
}

// isValidProof checks if the given proof is a valid one, comparing to current L2 node canonical chain.
func (p *Prover) isValidProof(
	ctx context.Context,
	blockID *big.Int,
	parentHash common.Hash,
	blockHash common.Hash,
	stateRoot common.Hash,
) (bool, error) {
	parent, err := p.rpc.L2ParentByBlockID(ctx, blockID)
	if err != nil {
		return false, err
	}

	l2Header, err := p.rpc.L2.HeaderByNumber(ctx, blockID)
	if err != nil {
		return false, err
	}

	l1Origin, err := p.rpc.L2.L1OriginByID(ctx, blockID)
	if err != nil {
		return false, err
	}

	l1Header, err := p.rpc.L1.HeaderByNumber(ctx, new(big.Int).Sub(l1Origin.L1BlockHeight, common.Big1))
	if err != nil {
		return false, err
	}

	return parent.Hash() == parentHash &&
		l2Header.Hash() == blockHash &&
		l1Header.Root == stateRoot, nil
}

// requestProofByBlockID performs a proving operation for the given block.
func (p *Prover) requestProofByBlockID(
	blockID *big.Int,
	l1Height *big.Int,
	minTier uint16,
	// If this event is not nil, then the prover will try contesting the transition.
	transitionProvedEvent *bindings.TaikoL1ClientTransitionProved,
) error {
	// NOTE: since this callback function will only be called after a L2 block's proving window is expired,
	// or a wrong proof's submission, so we won't check if L1 chain has been reorged here.
	onBlockProposed := func(
		ctx context.Context,
		event *bindings.TaikoL1ClientBlockProposed,
		end eventIterator.EndBlockProposedEventIterFunc,
	) error {
		// Only filter for exact blockID we want.
		if event.BlockId.Cmp(blockID) != 0 {
			return nil
		}

		// Check whether the block has been verified.
		isVerified, err := p.isBlockVerified(event.BlockId)
		if err != nil {
			return fmt.Errorf("failed to check if the current L2 block is verified: %w", err)
		}
		if isVerified {
			log.Info("📋 Block has been verified", "blockID", event.BlockId)
			return nil
		}

		if transitionProvedEvent != nil {
			return p.proofContester.SubmitContest(
				ctx,
				event.BlockId,
				new(big.Int).SetUint64(event.Raw.BlockNumber),
				transitionProvedEvent.Tran.ParentHash,
				&event.Meta,
				transitionProvedEvent.Tier,
			)
		}

		// If there is no proof submitter selected, skip proving it.
		if p.IsGuardianProver() {
			minTier = encoding.TierGuardianID
		}
		if proofSubmitter := p.selectSubmitter(minTier); proofSubmitter != nil {
			return proofSubmitter.RequestProof(ctx, event)
		}

		return nil
	}

	handleBlockProposedEvent := func() error {
		// Make sure `end` height is less than the latest L1 head.
		l1Head, err := p.rpc.L1.BlockNumber(p.ctx)
		if err != nil {
			log.Error("Failed to get L1 block head", "error", err)
			return err
		}
		end := new(big.Int).Add(l1Height, common.Big1)
		if end.Uint64() > l1Head {
			end = new(big.Int).SetUint64(l1Head)
		}

		iter, err := eventIterator.NewBlockProposedIterator(p.ctx, &eventIterator.BlockProposedIteratorConfig{
			Client:               p.rpc.L1,
			TaikoL1:              p.rpc.TaikoL1,
			StartHeight:          new(big.Int).Sub(l1Height, common.Big1),
			EndHeight:            end,
			OnBlockProposedEvent: onBlockProposed,
		})
		if err != nil {
			log.Error("Failed to start event iterator", "event", "BlockProposed", "error", err)
			return err
		}

		return iter.Iter()
	}

	go func() {
		if err := backoff.Retry(
			func() error {
				if err := handleBlockProposedEvent(); err != nil {
					log.Error(
						"Failed to handle BlockProposed event",
						"error", err,
						"blockID", blockID,
						"maxRetrys", p.cfg.BackOffMaxRetrys,
					)
					return err
				}
				return nil
			},
			backoff.WithMaxRetries(backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval), p.cfg.BackOffMaxRetrys),
		); err != nil {
			log.Error("Failed to request proof with a given block ID", "blockID", blockID, "error", err)
		}
	}()

	return nil
}

// onProvingWindowExpired tries to submit a proof for an expired block.
func (p *Prover) onProvingWindowExpired(ctx context.Context, e *bindings.TaikoL1ClientBlockProposed) error {
	log.Info(
		"Block proving window is expired",
		"blockID", e.BlockId,
		"assignedProver", e.AssignedProver,
		"minTier", e.Meta.MinTier,
	)
	// If proving window is expired, then the assigned prover can not submit new proofs for it anymore.
	if p.proverAddress == e.AssignedProver {
		return nil
	}
	// Check if we still need to generate a new proof for that block.
	proofStatus, err := rpc.GetBlockProofStatus(ctx, p.rpc, e.BlockId, p.proverAddress)
	if err != nil {
		return err
	}
	if proofStatus.IsSubmitted {
		// If there is already a proof submitted and there is no need to contest
		// it, we skip proving this block here.
		if !proofStatus.Invalid || !p.cfg.ContesterMode {
			return nil
		}

		return p.handleInvalidProof(
			ctx,
			e.BlockId,
			new(big.Int).SetUint64(e.Raw.BlockNumber),
			proofStatus.ParentHeader.Hash(),
			proofStatus.CurrentTransitionState.Contester,
			&e.Meta,
			proofStatus.CurrentTransitionState.Tier,
		)
	}

	return p.requestProofByBlockID(e.BlockId, new(big.Int).SetUint64(e.Raw.BlockNumber), e.Meta.MinTier, nil)
}

// getProvingWindow returns the provingWindow of the given proposed block.
func (p *Prover) getProvingWindow(e *bindings.TaikoL1ClientBlockProposed) (time.Duration, error) {
	for _, t := range p.tiers {
		if e.Meta.MinTier == t.ID {
			return time.Duration(t.ProvingWindow) * time.Minute, nil
		}
	}

	return 0, errTierNotFound
}

// selectSubmitter returns the proof submitter with the given minTier.
func (p *Prover) selectSubmitter(minTier uint16) proofSubmitter.Submitter {
	for _, s := range p.proofSubmitters {
		if s.Tier() >= minTier {
			return s
		}
	}

	log.Warn("No proof producer / submitter found for the given minTier", "minTier", minTier)

	return nil
}

// getSubmitterByTier returns the proof submitter with the given tier.
func (p *Prover) getSubmitterByTier(tier uint16) proofSubmitter.Submitter {
	for _, s := range p.proofSubmitters {
		if s.Tier() == tier {
			return s
		}
	}

	log.Warn("No proof producer / submitter found for the given tier", "tier", tier)

	return nil
}

// IsGuardianProver returns true if the current prover is a guardian prover.
func (p *Prover) IsGuardianProver() bool {
	return p.cfg.GuardianProverAddress != common.Address{}
}

// heartbeatInterval sends a heartbeat to the guardian prover health check server
// on an interval
func (p *Prover) heartbeatInterval(ctx context.Context) {
	t := time.NewTicker(heartbeatInterval)

	defer func() {
		t.Stop()
		p.wg.Done()
	}()

	// only guardianProvers should send heartbeat
	if !p.IsGuardianProver() {
		return
	}

	for {
		select {
		case <-p.ctx.Done():
			return
		case <-t.C:
			latestL1Block, err := p.rpc.L1.BlockNumber(ctx)
			if err != nil {
				log.Error("guardian prover error getting latestL1Block", err)
				continue
			}

			latestL2Block, err := p.rpc.L2.BlockNumber(ctx)
			if err != nil {
				log.Error("guardian prover error getting latestL2Block", err)
				continue
			}

			if err := p.guardianProverSender.SendHeartbeat(
				ctx,
				latestL1Block,
				latestL2Block,
			); err != nil {
				log.Error("Failed to send guardian prover heartbeat", "error", err)
			}
		}
	}
}
