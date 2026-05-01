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
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

// eventHandlers contains all event handlers which will be used by the prover.
type eventHandlers struct {
	proposalHandler          handler.ProposalHandler
	proofsReceivedHandler    handler.ProofsReceivedHandler
	assignmentExpiredHandler handler.AssignmentExpiredHandler
}

// Prover keeps trying to prove newly proposed inbox proposals.
type Prover struct {
	// Configurations
	cfg *Config

	// Clients
	rpc *rpc.Client

	// Contract configurations
	protocolConfigs config.ProtocolConfigs

	// States
	sharedState *state.SharedState

	// Event handlers
	eventHandlers *eventHandlers

	// Proof submitters
	proofSubmitter proofSubmitter.Submitter

	assignmentExpiredCh      chan metadata.TaikoProposalMetaData
	proveNotify              chan struct{}
	batchesAggregationNotify chan proofProducer.ProofType
	flushCacheNotify         chan proofProducer.ProofType

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

	// Clients
	if p.rpc, err = rpc.NewClient(p.ctx, &rpc.ClientConfig{
		L1Endpoint:         cfg.L1WsEndpoint,
		L1BeaconEndpoint:   cfg.L1BeaconEndpoint,
		L2Endpoint:         cfg.L2WsEndpoint,
		L2EngineEndpoint:   cfg.L2EngineEndpoint,
		JwtSecret:          cfg.JwtSecret,
		InboxAddress:       cfg.InboxAddress,
		TaikoAnchorAddress: cfg.TaikoAnchorAddress,
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
	p.batchesAggregationNotify = make(chan proofProducer.ProofType, proofSubmitter.MaxNumSupportedProofTypes)
	p.flushCacheNotify = make(chan proofProducer.ProofType, proofSubmitter.MaxNumSupportedProofTypes)

	if err := p.initL1Current(cfg.StartingProposalID); err != nil {
		return fmt.Errorf("initialize L1 current cursor error: %w", err)
	}

	txBuilder := transaction.NewProveBatchesTxBuilder(
		p.rpc,
		p.cfg.InboxAddress,
	)
	if txMgr != nil {
		p.txmgr = txMgr
	} else if p.txmgr, err = txmgr.NewSimpleTxManager(
		"prover",
		log.Root(),
		&metrics.TxMgrMetrics,
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	switch {
	case privateTxMgr != nil:
		p.privateTxmgr = privateTxMgr
	case cfg.PrivateTxmgrConfigs != nil && len(cfg.PrivateTxmgrConfigs.L1RPCURL) > 0:
		if p.privateTxmgr, err = txmgr.NewSimpleTxManager(
			"privateMempoolProver",
			log.Root(),
			&metrics.TxMgrMetrics,
			*cfg.PrivateTxmgrConfigs,
		); err != nil {
			return err
		}
	default:
		p.privateTxmgr = nil
	}

	// Proof submitter
	if err := p.initProofSubmitter(ctx, txBuilder); err != nil {
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
	// Start the main event loop of the prover.
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

	// If there are too many pending proposals in the Inbox contract, there will be no new proposal event temporarily, so
	// except the proposal-event subscription, we need another trigger to start fetching the proposed proposals.
	forceProvingTicker := time.NewTicker(15 * time.Second)
	defer forceProvingTicker.Stop()

	// Channels
	chBufferSize := p.protocolConfigs.MaxProposals()
	proposedCh := make(chan *shastaBindings.ShastaInboxClientProposed, chBufferSize)
	provedCh := make(chan *shastaBindings.ShastaInboxClientProved, chBufferSize)

	// Subscriptions. Prover requires --l1.ws (validated separately), so the WS
	// path is always taken; the leading L1 client is required by the helper.
	proposedSub := rpc.SubscribeProposed(p.rpc.L1, p.rpc.ShastaClients.Inbox, proposedCh)
	provedSub := rpc.SubscribeProved(p.rpc.L1, p.rpc.ShastaClients.Inbox, provedCh)
	defer func() {
		proposedSub.Unsubscribe()
		provedSub.Unsubscribe()
	}()

	for {
		select {
		case <-p.ctx.Done():
			return
		case batchProof := <-p.batchProofGenerationCh:
			p.withRetry(
				func() error { return p.submitProofAggregationOp(batchProof) },
				func() error { return p.clearProofBuffer(batchProof, true) },
			)
		case req := <-p.proofSubmissionCh:
			p.withRetry(func() error { return p.requestProofOp(req.Meta) }, nil)
		case <-p.proveNotify:
			if err := p.proveOp(); err != nil {
				log.Error("Prove new proposals error", "error", err)
			}
		case proofType := <-p.batchesAggregationNotify:
			p.withRetry(func() error { return p.aggregateOp(proofType) }, nil)
		case proofType := <-p.flushCacheNotify:
			p.withRetry(func() error { return p.proofSubmitter.FlushCache(p.ctx, proofType) }, nil)
		case m := <-p.assignmentExpiredCh:
			p.withRetry(func() error { return p.eventHandlers.assignmentExpiredHandler.Handle(p.ctx, m) }, nil)
		case <-proposedCh:
			reqProving()
		case e := <-provedCh:
			p.withRetry(func() error { return p.eventHandlers.proofsReceivedHandler.Handle(p.ctx, e) }, nil)
		case <-forceProvingTicker.C:
			reqProving()
		}
	}
}

// Close closes the prover instance.
func (p *Prover) Close(_ context.Context) {
	p.wg.Wait()
}

// proveOp iterates through Proposed events.
func (p *Prover) proveOp() error {
	iter, err := eventIterator.NewProposalIterator(p.ctx, &eventIterator.ProposalIteratorConfig{
		RpcClient:          p.rpc,
		StartHeight:        new(big.Int).SetUint64(p.sharedState.GetL1Current().Number.Uint64()),
		OnProposalEvent:    p.eventHandlers.proposalHandler.Handle,
		BlockConfirmations: &p.cfg.BlockConfirmations,
	})
	if err != nil {
		log.Error("Failed to start proposal iterator", "error", err)
		return err
	}

	return iter.Iter()
}

// aggregateOp aggregates all proofs in buffer.
func (p *Prover) aggregateOp(proofType proofProducer.ProofType) error {
	err := p.proofSubmitter.AggregateProofsByType(p.ctx, proofType)
	if err != nil {
		log.Error("Failed to aggregate proofs", "error", err, "proofType", proofType)
		return err
	}
	return nil
}

// requestProofOp requests a new proof generation operation.
func (p *Prover) requestProofOp(meta metadata.TaikoProposalMetaData) error {
	return p.proofSubmitter.RequestProof(p.ctx, meta)
}

// submitProofAggregationOp performs a batch proof submission operation.
func (p *Prover) submitProofAggregationOp(batchProof *proofProducer.BatchProofs) error {
	submitter, err := p.getSubmitter(batchProof)
	if err != nil {
		return err
	}
	if err := submitter.BatchSubmitProofs(p.ctx, batchProof); err != nil {
		if strings.Contains(err.Error(), proofSubmitter.ErrInvalidProof.Error()) {
			log.Warn(
				"Detected proven proposals",
				"proposalIDs", batchProof.BatchIDs,
				"proofType", batchProof.ProofType,
				"error", err,
			)
			return nil
		} else if strings.Contains(err.Error(), vm.ErrExecutionReverted.Error()) ||
			strings.Contains(err.Error(), transaction.ErrUnretryableSubmission.Error()) {
			log.Error(
				"Proof submission reverted or unretryable",
				"proposalIDs", batchProof.BatchIDs,
				"proofType", batchProof.ProofType,
				"error", err,
			)
			if err := submitter.ClearProofBuffers(batchProof, true); err != nil {
				// If clearing the proof buffer fails, return the error and retry in the next attempt.
				return err
			}
			return nil
		}
		log.Error(
			"Submit proof error",
			"proposalIDs", batchProof.BatchIDs,
			"proofType", batchProof.ProofType,
			"error", err,
		)
		return err
	}
	if err := submitter.ClearProofBuffers(batchProof, false); err != nil {
		return fmt.Errorf("failed to clear proof buffers after successful submission: %w", err)
	}

	return nil
}

// clearProofBuffer clears the buffered proof items for the proposal aggregation from the matching submitter.
func (p *Prover) clearProofBuffer(batchProof *proofProducer.BatchProofs, resend bool) error {
	submitter, err := p.getSubmitter(batchProof)
	if err != nil {
		return err
	}
	return submitter.ClearProofBuffers(batchProof, resend)
}

// getSubmitter returns the mapping proof submitter if it can be found.
func (p *Prover) getSubmitter(batchProof *proofProducer.BatchProofs) (proofSubmitter.Submitter, error) {
	if batchProof == nil || len(batchProof.ProofResponses) == 0 {
		return nil, fmt.Errorf("empty batch proof")
	}
	if p.proofSubmitter == nil {
		return nil, fmt.Errorf("submitter not found: %s", batchProof.ProofType)
	}
	return p.proofSubmitter, nil
}

// Name returns the application name.
func (p *Prover) Name() string {
	return "prover"
}

// ProverAddress returns the current prover account address.
func (p *Prover) ProverAddress() common.Address {
	return p.txmgr.From()
}

// withRetry retries the given function with prover backoff policy and runs callback if retries are exhausted.
func (p *Prover) withRetry(f func() error, callback func() error) {
	p.wg.Add(1)
	go func() {
		defer p.wg.Done()
		// Create a fresh, per-call backoff policy to avoid shared state across goroutines.
		bo := backoff.WithContext(
			backoff.WithMaxRetries(
				backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval),
				p.cfg.BackOffMaxRetries,
			),
			p.ctx,
		)
		if err := backoff.Retry(f, bo); err != nil {
			if callback != nil {
				callbackErr := callback()
				if callbackErr != nil {
					log.Error("Callback failed", "error", callbackErr)
				}
			}
			log.Error("Operation failed", "error", err)
		}
	}()
}
