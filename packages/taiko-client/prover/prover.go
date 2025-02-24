package prover

import (
	"context"
	"fmt"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/log"
	"github.com/pkg/errors"
	"github.com/urfave/cli/v2"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/version"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	guardianProverHeartbeater "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/guardian_prover_heartbeater"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

// eventHandlers contains all event handlers which will be used by the prover.
type eventHandlers struct {
	blockProposedHandler       handler.BlockProposedHandler
	blockVerifiedHandler       handler.BlockVerifiedHandler
	transitionContestedHandler handler.TransitionContestedHandler
	transitionProvedHandler    handler.TransitionProvedHandler
	assignmentExpiredHandler   handler.AssignmentExpiredHandler
}

// Prover keeps trying to prove newly proposed blocks.
type Prover struct {
	// Configurations
	cfg     *Config
	backoff backoff.BackOffContext

	// Clients
	rpc *rpc.Client

	// Guardian prover related
	guardianProverHeartbeater guardianProverHeartbeater.BlockSenderHeartbeater

	// Contract configurations
	protocolConfigs config.ProtocolConfigs

	// States
	sharedState *state.SharedState

	// Event handlers
	eventHandlers *eventHandlers

	// Proof submitters
	proofSubmittersOntake []proofSubmitter.Submitter
	proofContesterOntake  proofSubmitter.Contester
	proofSubmitterPacaya  proofSubmitter.Submitter

	assignmentExpiredCh chan metadata.TaikoProposalMetaData
	proveNotify         chan struct{}
	aggregationNotify   chan uint16

	// Proof related channels
	proofSubmissionCh      chan *proofProducer.ProofRequestBody
	proofContestCh         chan *proofProducer.ContestRequestBody
	proofGenerationCh      chan *proofProducer.ProofResponse
	batchProofGenerationCh chan *proofProducer.BatchProofs

	// Transactions manager
	txmgr        txmgr.TxManager
	privateTxmgr txmgr.TxManager

	ctx context.Context
	wg  sync.WaitGroup
}

// InitFromCli initializes the given prover instance based on the command line flags.
func (p *Prover) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, p, cfg, nil, nil)
}

// InitFromConfig initializes the prover instance based on the given configurations.
func InitFromConfig(
	ctx context.Context,
	p *Prover, cfg *Config,
	txMgr *txmgr.SimpleTxManager,
	privateTxMgr *txmgr.SimpleTxManager,
) (err error) {
	p.cfg = cfg
	p.ctx = ctx
	// Initialize state which will be shared by event handlers.
	p.sharedState = state.New()
	p.backoff = backoff.WithContext(
		backoff.WithMaxRetries(
			backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval),
			p.cfg.BackOffMaxRetries,
		),
		p.ctx,
	)

	// Clients
	if p.rpc, err = rpc.NewClient(p.ctx, &rpc.ClientConfig{
		L1Endpoint:                    cfg.L1WsEndpoint,
		L2Endpoint:                    cfg.L2WsEndpoint,
		TaikoL1Address:                cfg.TaikoL1Address,
		TaikoL2Address:                cfg.TaikoL2Address,
		TaikoTokenAddress:             cfg.TaikoTokenAddress,
		ProverSetAddress:              cfg.ProverSetAddress,
		GuardianProverMinorityAddress: cfg.GuardianProverMinorityAddress,
		GuardianProverMajorityAddress: cfg.GuardianProverMajorityAddress,
		Timeout:                       cfg.RPCTimeout,
	}); err != nil {
		return err
	}

	// Configs
	p.protocolConfigs, err = p.rpc.GetProtocolConfigs(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}
	config.ReportProtocolConfigs(p.protocolConfigs)

	chBufferSize := p.protocolConfigs.MaxProposals()
	p.proofGenerationCh = make(chan *proofProducer.ProofResponse, chBufferSize)
	p.batchProofGenerationCh = make(chan *proofProducer.BatchProofs, chBufferSize)
	p.assignmentExpiredCh = make(chan metadata.TaikoProposalMetaData, chBufferSize)
	p.proofSubmissionCh = make(chan *proofProducer.ProofRequestBody, chBufferSize)
	p.proofContestCh = make(chan *proofProducer.ContestRequestBody, chBufferSize)
	p.proveNotify = make(chan struct{}, 1)
	p.aggregationNotify = make(chan uint16, 1)

	if err := p.initL1Current(cfg.StartingBlockID); err != nil {
		return fmt.Errorf("initialize L1 current cursor error: %w", err)
	}

	// Protocol proof tiers
	if err := p.initProofTiers(ctx); err != nil {
		log.Warn("Initialize proof tiers error", "error", err)
	}

	txBuilder := transaction.NewProveBlockTxBuilder(
		p.rpc,
		p.cfg.TaikoL1Address,
		p.cfg.ProverSetAddress,
		p.cfg.GuardianProverMajorityAddress,
		p.cfg.GuardianProverMinorityAddress,
	)

	if txMgr != nil {
		p.txmgr = txMgr
	} else {
		if p.txmgr, err = txmgr.NewSimpleTxManager(
			"prover",
			log.Root(),
			&metrics.TxMgrMetrics,
			*cfg.TxmgrConfigs,
		); err != nil {
			return err
		}
	}

	if privateTxMgr != nil {
		p.privateTxmgr = privateTxMgr
	} else {
		if cfg.PrivateTxmgrConfigs != nil && len(cfg.PrivateTxmgrConfigs.L1RPCURL) > 0 {
			if p.privateTxmgr, err = txmgr.NewSimpleTxManager(
				"privateMempoolProver",
				log.Root(),
				&metrics.TxMgrMetrics,
				*cfg.PrivateTxmgrConfigs,
			); err != nil {
				return err
			}
		} else {
			p.privateTxmgr = nil
		}
	}

	// Proof submitters
	if err := p.initProofSubmitters(txBuilder, p.sharedState.GetTiers()); err != nil {
		return err
	}

	// Proof contester
	p.proofContesterOntake = proofSubmitter.NewProofContester(
		p.rpc,
		p.cfg.ProveBlockGasLimit,
		p.txmgr,
		p.privateTxmgr,
		p.cfg.ProverSetAddress,
		p.cfg.Graffiti,
		txBuilder,
	)

	// Guardian prover heartbeat sender
	if p.IsGuardianProver() && p.cfg.GuardianProverHealthCheckServerEndpoint != nil {
		// Check guardian prover contract address is correct.
		if _, err := p.rpc.OntakeClients.GuardianProverMajority.MinGuardians(&bind.CallOpts{Context: ctx}); err != nil {
			return fmt.Errorf("failed to get MinGuardians from majority guardian prover contract: %w", err)
		}

		if p.rpc.OntakeClients.GuardianProverMinority != nil {
			if _, err := p.rpc.OntakeClients.GuardianProverMinority.MinGuardians(&bind.CallOpts{Context: ctx}); err != nil {
				return fmt.Errorf("failed to get MinGuardians from minority guardian prover contract: %w", err)
			}
		}

		p.guardianProverHeartbeater = guardianProverHeartbeater.New(
			p.cfg.L1ProverPrivKey,
			p.cfg.GuardianProverHealthCheckServerEndpoint,
			p.rpc,
			p.ProverAddress(),
		)
	}

	// Initialize event handlers.
	if err := p.initEventHandlers(); err != nil {
		return err
	}

	return nil
}

// Start starts the main loop of the L2 block prover.
func (p *Prover) Start() error {
	// 1. Set approval amount for the contracts.
	for _, contract := range []common.Address{p.cfg.TaikoL1Address} {
		if err := p.setApprovalAmount(p.ctx, contract); err != nil {
			log.Crit("Failed to set approval amount", "contract", contract, "error", err)
		}
	}

	// 2. Start the guardian prover heartbeat sender if the current prover is a guardian prover.
	if p.IsGuardianProver() && p.cfg.GuardianProverHealthCheckServerEndpoint != nil {
		// Send the startup message to the guardian prover health check server.
		if err := p.guardianProverHeartbeater.SendStartupMessage(
			p.ctx,
			version.CommitVersion(),
			version.CommitVersion(),
			p.cfg.L1NodeVersion,
			p.cfg.L2NodeVersion,
		); err != nil {
			log.Error("Failed to send guardian prover startup message", "error", err)
		}

		// Start the guardian prover heartbeat loop.
		go p.guardianProverHeartbeatLoop(p.ctx)
	}

	// 3. Start the main event loop of the prover.
	go p.eventLoop()

	return nil
}

// eventLoop starts the main loop of Taiko prover.
func (p *Prover) eventLoop() {
	p.wg.Add(1)
	defer p.wg.Done()

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
	// BlockProposed event temporarily, so except the BlockProposed subscription, we need another trigger to start
	// fetching the proposed blocks.
	forceProvingTicker := time.NewTicker(15 * time.Second)
	defer forceProvingTicker.Stop()

	// Channels
	chBufferSize := p.protocolConfigs.MaxProposals()
	blockProposedV2Ch := make(chan *ontakeBindings.TaikoL1ClientBlockProposedV2, chBufferSize)
	blockVerifiedV2Ch := make(chan *ontakeBindings.TaikoL1ClientBlockVerifiedV2, chBufferSize)
	transitionProvedV2Ch := make(chan *ontakeBindings.TaikoL1ClientTransitionProvedV2, chBufferSize)
	transitionContestedV2Ch := make(chan *ontakeBindings.TaikoL1ClientTransitionContestedV2, chBufferSize)
	batchProposedCh := make(chan *pacayaBindings.TaikoInboxClientBatchProposed, chBufferSize)
	batchesVerifiedCh := make(chan *pacayaBindings.TaikoInboxClientBatchesVerified, chBufferSize)
	batchesProvedCh := make(chan *pacayaBindings.TaikoInboxClientBatchesProved, chBufferSize)
	// Subscriptions
	blockProposedV2Sub := rpc.SubscribeBlockProposedV2(p.rpc.OntakeClients.TaikoL1, blockProposedV2Ch)
	blockVerifiedV2Sub := rpc.SubscribeBlockVerifiedV2(p.rpc.OntakeClients.TaikoL1, blockVerifiedV2Ch)
	transitionProvedV2Sub := rpc.SubscribeTransitionProvedV2(p.rpc.OntakeClients.TaikoL1, transitionProvedV2Ch)
	transitionContestedV2Sub := rpc.SubscribeTransitionContestedV2(p.rpc.OntakeClients.TaikoL1, transitionContestedV2Ch)
	batchProposedSub := rpc.SubscribeBatchProposedPacaya(p.rpc.PacayaClients.TaikoInbox, batchProposedCh)
	batchesVerifiedSub := rpc.SubscribeBatchesVerifiedPacaya(p.rpc.PacayaClients.TaikoInbox, batchesVerifiedCh)
	batchesProvedSub := rpc.SubscribeBatchesProvedPacaya(p.rpc.PacayaClients.TaikoInbox, batchesProvedCh)
	defer func() {
		blockProposedV2Sub.Unsubscribe()
		blockVerifiedV2Sub.Unsubscribe()
		transitionProvedV2Sub.Unsubscribe()
		transitionContestedV2Sub.Unsubscribe()
		batchProposedSub.Unsubscribe()
		batchesVerifiedSub.Unsubscribe()
		batchesProvedSub.Unsubscribe()
	}()

	for {
		select {
		case <-p.ctx.Done():
			return
		case req := <-p.proofContestCh:
			p.withRetry(func() error { return p.contestProofOp(req) })
		case proofResponse := <-p.proofGenerationCh:
			p.withRetry(func() error { return p.submitProofOp(proofResponse) })
		case batchProof := <-p.batchProofGenerationCh:
			p.withRetry(func() error { return p.submitProofAggregationOp(batchProof) })
		case req := <-p.proofSubmissionCh:
			p.withRetry(func() error { return p.requestProofOp(req.Meta, req.Tier) })
		case <-p.proveNotify:
			if err := p.proveOp(); err != nil {
				log.Error("Prove new blocks error", "error", err)
			}
		case tier := <-p.aggregationNotify:
			p.withRetry(func() error { return p.aggregateOp(tier) })
		case e := <-blockVerifiedV2Ch:
			p.eventHandlers.blockVerifiedHandler.Handle(e)
		case e := <-transitionProvedV2Ch:
			p.withRetry(func() error {
				return p.eventHandlers.transitionProvedHandler.Handle(p.ctx, e)
			})
		case e := <-transitionContestedV2Ch:
			p.withRetry(func() error {
				return p.eventHandlers.transitionContestedHandler.Handle(p.ctx, e)
			})
		case m := <-p.assignmentExpiredCh:
			p.withRetry(func() error { return p.eventHandlers.assignmentExpiredHandler.Handle(p.ctx, m) })
		case <-blockProposedV2Ch:
			reqProving()
		case <-batchProposedCh:
			reqProving()
		case <-forceProvingTicker.C:
			reqProving()
		}
	}
}

// Close closes the prover instance.
func (p *Prover) Close(_ context.Context) {
	p.wg.Wait()
}

// proveOp iterates through BlockProposed events.
func (p *Prover) proveOp() error {
	iter, err := eventIterator.NewBlockProposedIterator(p.ctx, &eventIterator.BlockProposedIteratorConfig{
		Client:               p.rpc.L1,
		TaikoL1:              p.rpc.OntakeClients.TaikoL1,
		TaikoInbox:           p.rpc.PacayaClients.TaikoInbox,
		PacayaForkHeight:     p.rpc.PacayaClients.ForkHeight,
		StartHeight:          new(big.Int).SetUint64(p.sharedState.GetL1Current().Number.Uint64()),
		OnBlockProposedEvent: p.eventHandlers.blockProposedHandler.Handle,
		BlockConfirmations:   &p.cfg.BlockConfirmations,
	})
	if err != nil {
		log.Error("Failed to start event iterator", "event", "BlockProposed", "error", err)
		return err
	}

	return iter.Iter()
}

// aggregateOp aggregates all proofs in buffer.
func (p *Prover) aggregateOp(tier uint16) error {
	g, gCtx := errgroup.WithContext(p.ctx)
	for _, submitter := range p.proofSubmittersOntake {
		g.Go(func() error {
			if submitter.AggregationEnabled() && submitter.Tier() == tier {
				if err := submitter.AggregateProofs(gCtx); err != nil {
					log.Error(
						"Failed to aggregate proofs",
						"error", err,
						"tier", submitter.Tier(),
					)
					return err
				}
			} else {
				log.Debug(
					"Skip the current aggregation operation",
					"requestTier", tier,
					"submitterTier", submitter.Tier(),
					"bufferSize", submitter.BufferSize(),
				)
			}
			return nil
		})
	}

	return g.Wait()
}

// contestProofOp performs a proof contest operation.
func (p *Prover) contestProofOp(req *proofProducer.ContestRequestBody) error {
	if err := p.proofContesterOntake.SubmitContest(
		p.ctx,
		req.BlockID,
		req.ProposedIn,
		req.ParentHash,
		req.Meta,
		req.Tier,
	); err != nil {
		if strings.Contains(err.Error(), vm.ErrExecutionReverted.Error()) {
			log.Error(
				"Proof contest submission reverted",
				"blockID", req.BlockID,
				"minTier", req.Meta.Ontake().GetMinTier(),
				"error", err,
			)
			return nil
		}
		log.Error(
			"Request new proof contest error",
			"blockID", req.BlockID,
			"minTier", req.Meta.Ontake().GetMinTier(),
			"error", err,
		)
		return err
	}

	return nil
}

// requestProofOp requests a new proof generation operation.
func (p *Prover) requestProofOp(meta metadata.TaikoProposalMetaData, minTier uint16) error {
	if meta.IsPacaya() {
		if err := p.proofSubmitterPacaya.RequestProof(p.ctx, meta); err != nil {
			log.Error(
				"Request new batch proof error",
				"batchID", meta.Pacaya().GetBatchID(),
				"error", err,
			)
			return err
		}

		return nil
	}
	if p.IsGuardianProver() {
		if minTier > encoding.TierGuardianMinorityID {
			minTier = encoding.TierGuardianMajorityID
		} else {
			minTier = encoding.TierGuardianMinorityID
		}
	}
	if minTier == encoding.TierOptimisticID ||
		minTier >= encoding.TierGuardianMinorityID ||
		len(p.cfg.RaikoZKVMHostEndpoint) == 0 {
		if submitter := p.selectSubmitter(minTier); submitter != nil {
			if err := submitter.RequestProof(p.ctx, meta); err != nil {
				log.Error(
					"Request new proof error",
					"blockID", meta.Ontake().GetBlockID(),
					"minTier", meta.Ontake().GetMinTier(),
					"error", err,
				)
				return err
			}

			return nil
		}
	} else {
		if submitter := p.selectSubmitter(encoding.TierZkVMSp1ID); submitter != nil {
			if err := submitter.RequestProof(p.ctx, meta); err != nil {
				if errors.Is(err, proofProducer.ErrZkAnyNotDrawn) {
					log.Debug("ZK proof was not chosen, attempting to request SGX proof",
						"blockID", meta.Ontake().GetBlockID(),
					)
					if sgxSubmitter := p.selectSubmitter(encoding.TierSgxID); sgxSubmitter != nil {
						if err := sgxSubmitter.RequestProof(p.ctx, meta); err != nil {
							log.Error(
								"Request new proof error",
								"blockID", meta.Ontake().GetBlockID(),
								"proofType", "sgx",
								"error", err,
							)
							return err
						}
						return nil
					}
				} else {
					log.Error(
						"Request new proof error",
						"blockID", meta.Ontake().GetBlockID(),
						"proofType", "zkAny",
						"error", err,
					)
					return err
				}
			} else {
				return nil
			}
		}
	}

	log.Error(
		"Failed to find proof submitter",
		"blockID", meta.Ontake().GetBlockID(),
		"minTier", minTier,
	)
	return nil
}

// submitProofOp performs a proof submission operation.
func (p *Prover) submitProofOp(proofResponse *proofProducer.ProofResponse) error {
	var submitter proofSubmitter.Submitter
	if proofResponse.Meta.IsPacaya() {
		submitter = p.proofSubmitterPacaya
	} else {
		submitter = p.getSubmitterByTier(proofResponse.Meta.Ontake().GetMinTier())
	}
	if submitter == nil {
		return nil
	}

	if err := submitter.SubmitProof(p.ctx, proofResponse); err != nil {
		if strings.Contains(err.Error(), vm.ErrExecutionReverted.Error()) {
			log.Error(
				"Proof submission reverted",
				"blockID", proofResponse.BlockID,
				"error", err,
			)
			return nil
		}
		log.Error(
			"Submit proof error",
			"blockID", proofResponse.BlockID,
			"error", err,
		)
		return err
	}

	return nil
}

// submitProofsOp performs a batch proof submission operation.
func (p *Prover) submitProofAggregationOp(batchProof *proofProducer.BatchProofs) error {
	submitter := p.getSubmitterByTier(batchProof.Tier)
	if submitter == nil {
		return nil
	}

	if err := submitter.BatchSubmitProofs(p.ctx, batchProof); err != nil {
		if strings.Contains(err.Error(), vm.ErrExecutionReverted.Error()) {
			log.Error(
				"Proof submission reverted",
				"blockIDs", batchProof.BlockIDs,
				"tier", batchProof.Tier,
				"error", err,
			)
			return nil
		} else if strings.Contains(err.Error(), proofSubmitter.ErrInvalidProof.Error()) {
			log.Warn(
				"Detected proven blocks",
				"blockIDs", batchProof.BlockIDs,
				"tier", batchProof.Tier,
				"error", err,
			)
			return nil
		}
		log.Error(
			"Submit proof error",
			"blockIDs", batchProof.BlockIDs,
			"tier", batchProof.Tier,
			"error", err,
		)
		return err
	}

	return nil
}

// Name returns the application name.
func (p *Prover) Name() string {
	return "prover"
}

// selectSubmitter returns the proof submitter with the given minTier.
func (p *Prover) selectSubmitter(minTier uint16) proofSubmitter.Submitter {
	for _, s := range p.proofSubmittersOntake {
		if s.Tier() >= minTier {
			if !p.IsGuardianProver() && s.Tier() >= encoding.TierGuardianMinorityID {
				continue
			}
			log.Debug("Proof submitter selected", "tier", s.Tier(), "minTier", minTier)
			return s
		}
	}

	log.Warn("No proof producer / submitter found for the given minTier", "minTier", minTier)

	return nil
}

// getSubmitterByTier returns the proof submitter with the given tier.
func (p *Prover) getSubmitterByTier(tier uint16) proofSubmitter.Submitter {
	for _, s := range p.proofSubmittersOntake {
		if s.Tier() == tier {
			if !p.IsGuardianProver() && s.Tier() >= encoding.TierGuardianMinorityID {
				continue
			}

			return s
		}
	}

	log.Warn("No proof producer / submitter found for the given tier", "tier", tier)

	return nil
}

// IsGuardianProver returns true if the current prover is a guardian prover.
func (p *Prover) IsGuardianProver() bool {
	return p.cfg.GuardianProverMajorityAddress != common.Address{}
}

// ProverAddress returns the current prover account address.
func (p *Prover) ProverAddress() common.Address {
	return p.txmgr.From()
}

// withRetry retries the given function with prover backoff policy.
func (p *Prover) withRetry(f func() error) {
	p.wg.Add(1)
	go func() {
		defer p.wg.Done()
		if err := backoff.Retry(f, p.backoff); err != nil {
			log.Error("Operation failed", "error", err)
		}
	}()
}
