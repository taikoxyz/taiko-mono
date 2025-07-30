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
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

// eventHandlers contains all event handlers which will be used by the prover.
type eventHandlers struct {
	batchProposedHandler     handler.BatchProposedHandler
	batchesVerifiedHandler   handler.BatchesVerifiedHandler
	batchesProvedHandler     handler.BatchesProvedHandler
	assignmentExpiredHandler handler.AssignmentExpiredHandler
}

// Prover keeps trying to prove newly proposed blocks.
type Prover struct {
	// Configurations
	cfg     *Config
	backoff backoff.BackOffContext

	// Clients
	rpc *rpc.Client

	// Contract configurations
	protocolConfigs config.ProtocolConfigs

	// States
	sharedState *state.SharedState

	// Event handlers
	eventHandlers *eventHandlers

	// Proof submitters
	proofSubmitterPacaya proofSubmitter.Submitter

	assignmentExpiredCh      chan metadata.TaikoProposalMetaData
	proveNotify              chan struct{}
	batchesAggregationNotify chan proofProducer.ProofType

	// Proof related channels
	proofSubmissionCh      chan *proofProducer.ProofRequestBody
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
		L1Endpoint:         cfg.L1WsEndpoint,
		L2Endpoint:         cfg.L2WsEndpoint,
		TaikoInboxAddress:  cfg.TaikoInboxAddress,
		TaikoAnchorAddress: cfg.TaikoAnchorAddress,
		TaikoTokenAddress:  cfg.TaikoTokenAddress,
		ProverSetAddress:   cfg.ProverSetAddress,
		Timeout:            cfg.RPCTimeout,
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
	p.batchProofGenerationCh = make(chan *proofProducer.BatchProofs, chBufferSize)
	p.assignmentExpiredCh = make(chan metadata.TaikoProposalMetaData, chBufferSize)
	p.proofSubmissionCh = make(chan *proofProducer.ProofRequestBody, chBufferSize)
	p.proveNotify = make(chan struct{}, 1)
	p.batchesAggregationNotify = make(chan proofProducer.ProofType, 1)

	if err := p.initL1Current(cfg.StartingBatchID); err != nil {
		return fmt.Errorf("initialize L1 current cursor error: %w", err)
	}

	txBuilder := transaction.NewProveBatchesTxBuilder(
		p.rpc,
		p.cfg.TaikoInboxAddress,
		p.cfg.ProverSetAddress,
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
	if err := p.initPacayaProofSubmitter(txBuilder); err != nil {
		return err
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
	for _, contract := range []common.Address{p.cfg.TaikoInboxAddress} {
		if err := p.setApprovalAmount(p.ctx, contract); err != nil {
			log.Crit("Failed to set approval amount", "contract", contract, "error", err)
		}
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

	// If there is too many (TaikoData.Config.blockMaxProposals) pending blocks in TaikoInbox contract, there will be no
	// new BatchProposed event temporarily, so except the BatchProposed subscription, we need another trigger to start
	// fetching the proposed batches.
	forceProvingTicker := time.NewTicker(15 * time.Second)
	defer forceProvingTicker.Stop()

	// Channels
	chBufferSize := p.protocolConfigs.MaxProposals()
	batchProposedCh := make(chan *pacayaBindings.TaikoInboxClientBatchProposed, chBufferSize)
	batchesVerifiedCh := make(chan *pacayaBindings.TaikoInboxClientBatchesVerified, chBufferSize)
	batchesProvedCh := make(chan *pacayaBindings.TaikoInboxClientBatchesProved, chBufferSize)
	// Subscriptions
	batchProposedSub := rpc.SubscribeBatchProposedPacaya(p.rpc.PacayaClients.TaikoInbox, batchProposedCh)
	batchesVerifiedSub := rpc.SubscribeBatchesVerifiedPacaya(p.rpc.PacayaClients.TaikoInbox, batchesVerifiedCh)
	batchesProvedSub := rpc.SubscribeBatchesProvedPacaya(p.rpc.PacayaClients.TaikoInbox, batchesProvedCh)
	defer func() {
		batchProposedSub.Unsubscribe()
		batchesVerifiedSub.Unsubscribe()
		batchesProvedSub.Unsubscribe()
	}()

	for {
		select {
		case <-p.ctx.Done():
			return
		case batchProof := <-p.batchProofGenerationCh:
			p.withRetry(func() error { return p.submitProofAggregationOp(batchProof) })
		case req := <-p.proofSubmissionCh:
			p.withRetry(func() error { return p.requestProofOp(req.Meta) })
		case <-p.proveNotify:
			if err := p.proveOp(); err != nil {
				log.Error("Prove new blocks error", "error", err)
			}
		case proofType := <-p.batchesAggregationNotify:
			p.withRetry(func() error { return p.aggregateOpPacaya(proofType) })
		case e := <-batchesVerifiedCh:
			if err := p.eventHandlers.batchesVerifiedHandler.HandlePacaya(p.ctx, e); err != nil {
				log.Error("Failed to handle new BatchesVerified event", "error", err)
			}
		case e := <-batchesProvedCh:
			p.withRetry(func() error { return p.eventHandlers.batchesProvedHandler.HandlePacaya(p.ctx, e) })
		case m := <-p.assignmentExpiredCh:
			p.withRetry(func() error { return p.eventHandlers.assignmentExpiredHandler.Handle(p.ctx, m) })
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

// proveOp iterates through BatchProposed events.
func (p *Prover) proveOp() error {
	iter, err := eventIterator.NewBatchProposedIterator(p.ctx, &eventIterator.BatchProposedIteratorConfig{
		Client:               p.rpc.L1,
		TaikoInbox:           p.rpc.PacayaClients.TaikoInbox,
		StartHeight:          new(big.Int).SetUint64(p.sharedState.GetL1Current().Number.Uint64()),
		OnBatchProposedEvent: p.eventHandlers.batchProposedHandler.Handle,
		BlockConfirmations:   &p.cfg.BlockConfirmations,
	})
	if err != nil {
		log.Error("Failed to start event iterator", "event", "BatchProposed", "error", err)
		return err
	}

	return iter.Iter()
}

// aggregateOpPacaya aggregates all proofs in buffer for Pacaya.
func (p *Prover) aggregateOpPacaya(proofType proofProducer.ProofType) error {
	if err := p.proofSubmitterPacaya.AggregateProofsByType(p.ctx, proofType); err != nil {
		log.Error("Failed to aggregate proofs", "error", err, "proofType", proofType)
		return err
	}
	return nil
}

// requestProofOp requests a new proof generation operation.
func (p *Prover) requestProofOp(meta metadata.TaikoProposalMetaData) error {
	if err := p.proofSubmitterPacaya.RequestProof(p.ctx, meta); err != nil {
		log.Error("Request new batch proof error", "batchID", meta.Pacaya().GetBatchID(), "error", err)
		return err
	}

	return nil
}

// submitProofAggregationOp performs a batch proof submission operation.
func (p *Prover) submitProofAggregationOp(batchProof *proofProducer.BatchProofs) error {
	submitter := p.proofSubmitterPacaya
	if utils.IsNil(submitter) {
		return fmt.Errorf("submitter not found: %s", batchProof.ProofType)
	}

	if err := submitter.BatchSubmitProofs(p.ctx, batchProof); err != nil {
		if strings.Contains(err.Error(), vm.ErrExecutionReverted.Error()) {
			log.Error(
				"Proof submission reverted",
				"blockIDs", batchProof.BatchIDs,
				"proofType", batchProof.ProofType,
				"error", err,
			)
			return nil
		} else if strings.Contains(err.Error(), proofSubmitter.ErrInvalidProof.Error()) {
			log.Warn(
				"Detected proven blocks",
				"blockIDs", batchProof.BatchIDs,
				"proofType", batchProof.ProofType,
				"error", err,
			)
			return nil
		}
		log.Error(
			"Submit proof error",
			"blockIDs", batchProof.BatchIDs,
			"proofType", batchProof.ProofType,
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
