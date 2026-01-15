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

const (
	l1EventPollInterval = time.Second
	l1LogPollMaxRange   = uint64(1000)
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
	proofSubmitterPacaya proofSubmitter.Submitter
	proofSubmitterShasta proofSubmitter.Submitter

	assignmentExpiredCh            chan metadata.TaikoProposalMetaData
	proveNotify                    chan struct{}
	batchesAggregationNotifyPacaya chan proofProducer.ProofType
	batchesAggregationNotifyShasta chan proofProducer.ProofType
	flushCacheNotify               chan proofProducer.ProofType

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
		L1Endpoint:         cfg.L1HttpEndpoint,
		L2Endpoint:         cfg.L2WsEndpoint,
		PacayaInboxAddress: cfg.PacayaInboxAddress,
		ShastaInboxAddress: cfg.ShastaInboxAddress,
		TaikoAnchorAddress: cfg.TaikoAnchorAddress,
		TaikoTokenAddress:  cfg.TaikoTokenAddress,
		ProverSetAddress:   cfg.ProverSetAddress,
		Timeout:            cfg.RPCTimeout,
		ShastaForkTime:     cfg.ShastaForkTime,
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
	p.batchesAggregationNotifyPacaya = make(chan proofProducer.ProofType, proofSubmitter.MaxNumSupportedProofTypes)
	p.batchesAggregationNotifyShasta = make(chan proofProducer.ProofType, proofSubmitter.MaxNumSupportedProofTypes)
	p.flushCacheNotify = make(chan proofProducer.ProofType, 1)

	if err := p.initL1Current(cfg.StartingBatchID); err != nil {
		return fmt.Errorf("initialize L1 current cursor error: %w", err)
	}

	txBuilder := transaction.NewProveBatchesTxBuilder(
		p.rpc,
		p.cfg.PacayaInboxAddress,
		p.cfg.ShastaInboxAddress,
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
	if err := p.initShastaProofSubmitter(ctx, txBuilder); err != nil {
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
	for _, contract := range []common.Address{p.cfg.PacayaInboxAddress} {
		if err := p.setApprovalAmount(p.ctx, contract); err != nil {
			log.Crit("Failed to set approval amount", "contract", contract, "error", err)
		}
	}

	// 2. Start the main event loop of the prover.
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

	l1EventPoller := time.NewTicker(l1EventPollInterval)
	defer l1EventPoller.Stop()

	var (
		lastL1HeadNumber      uint64
		lastL1HeadHash        common.Hash
		lastConfirmedBlock    uint64
		lastConfirmedHash     common.Hash
		lastConfirmedHashInit bool
	)
	if head, err := p.rpc.L1.BlockNumber(p.ctx); err != nil {
		log.Warn("Failed to fetch initial L1 head number", "error", err)
	} else {
		lastL1HeadNumber = head
		if header, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(head)); err != nil {
			log.Warn("Failed to fetch initial L1 head header", "error", err, "height", head)
		} else {
			lastL1HeadHash = header.Hash()
		}
		if confirmed, ok := confirmedL1Block(head, p.cfg.BlockConfirmations); ok {
			lastConfirmedBlock = confirmed
			if confirmed != head {
				if header, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(confirmed)); err != nil {
					log.Warn("Failed to fetch initial confirmed L1 header", "error", err, "height", confirmed)
				} else {
					lastConfirmedHash = header.Hash()
					lastConfirmedHashInit = true
				}
			} else if lastL1HeadHash != (common.Hash{}) {
				lastConfirmedHash = lastL1HeadHash
				lastConfirmedHashInit = true
			}
		}
	}

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
		case proofType := <-p.batchesAggregationNotifyPacaya:
			p.withRetry(func() error { return p.aggregateOp(proofType, false) })
		case proofType := <-p.batchesAggregationNotifyShasta:
			p.withRetry(func() error { return p.aggregateOp(proofType, true) })
		case proofType := <-p.flushCacheNotify:
			p.withRetry(func() error { return p.proofSubmitterShasta.FlushCache(p.ctx, proofType) })
		case m := <-p.assignmentExpiredCh:
			p.withRetry(func() error { return p.eventHandlers.assignmentExpiredHandler.Handle(p.ctx, m) })
		case <-l1EventPoller.C:
			head, err := p.rpc.L1.BlockNumber(p.ctx)
			if err != nil {
				log.Warn("Failed to poll L1 head number", "error", err)
				continue
			}
			headHeader, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(head))
			if err != nil {
				log.Warn("Failed to fetch L1 head header", "error", err, "height", head)
				continue
			}
			headHash := headHeader.Hash()
			if head != lastL1HeadNumber {
				if head > lastL1HeadNumber {
					reqProving()
				} else {
					log.Warn("L1 head regressed", "from", lastL1HeadNumber, "to", head)
				}
			} else if headHash != lastL1HeadHash {
				log.Warn(
					"L1 head hash changed",
					"height", head,
					"hash", headHash,
					"previous", lastL1HeadHash,
				)
				reqProving()
			}
			lastL1HeadNumber = head
			lastL1HeadHash = headHash

			confirmedHead, ok := confirmedL1Block(head, p.cfg.BlockConfirmations)
			if !ok {
				continue
			}
			confirmedHeader := headHeader
			if confirmedHead != head {
				confirmedHeader, err = p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(confirmedHead))
				if err != nil {
					log.Warn("Failed to fetch confirmed L1 head header", "error", err, "height", confirmedHead)
					continue
				}
			}
			confirmedHash := confirmedHeader.Hash()
			start := lastConfirmedBlock + 1
			if confirmedHead < lastConfirmedBlock {
				log.Warn("L1 confirmed head moved backwards", "from", lastConfirmedBlock, "to", confirmedHead)
				start = confirmedHead
			} else if confirmedHead == lastConfirmedBlock && lastConfirmedHashInit && confirmedHash != lastConfirmedHash {
				log.Warn(
					"L1 confirmed head hash changed",
					"height", confirmedHead,
					"hash", confirmedHash,
					"previous", lastConfirmedHash,
				)
				start = confirmedHead
			}
			if !lastConfirmedHashInit {
				lastConfirmedHash = confirmedHash
				lastConfirmedHashInit = true
			}
			if start <= confirmedHead {
				if err := p.pollL1Events(p.ctx, start, confirmedHead); err != nil {
					log.Warn("Failed to poll L1 protocol events", "error", err)
				} else {
					lastConfirmedBlock = confirmedHead
					lastConfirmedHash = confirmedHash
					lastConfirmedHashInit = true
				}
			}
		case <-forceProvingTicker.C:
			reqProving()
		}
	}
}

// Close closes the prover instance.
func (p *Prover) Close(_ context.Context) {
	p.wg.Wait()
}

func confirmedL1Block(head uint64, confirmations uint64) (uint64, bool) {
	if confirmations == 0 {
		return head, true
	}
	if head < confirmations {
		return 0, false
	}
	return head - confirmations, true
}

func (p *Prover) pollL1Events(ctx context.Context, start, end uint64) error {
	if start > end {
		return nil
	}
	for from := start; from <= end; {
		to := from + l1LogPollMaxRange - 1
		if to < from || to > end {
			to = end
		}
		if err := p.handleL1EventRange(ctx, from, to); err != nil {
			return err
		}
		if to == end {
			break
		}
		from = to + 1
	}
	return nil
}

func (p *Prover) handleL1EventRange(ctx context.Context, start, end uint64) error {
	endHeight := end
	opts := &bind.FilterOpts{Start: start, End: &endHeight, Context: ctx}

	verifiedIter, err := p.rpc.PacayaClients.TaikoInbox.FilterBatchesVerified(opts)
	if err != nil {
		return err
	}
	defer verifiedIter.Close()
	for verifiedIter.Next() {
		if err := p.eventHandlers.batchesVerifiedHandler.HandlePacaya(ctx, verifiedIter.Event); err != nil {
			log.Error("Failed to handle new BatchesVerified event", "error", err)
		}
	}
	if err := verifiedIter.Error(); err != nil {
		return err
	}

	provedIter, err := p.rpc.PacayaClients.TaikoInbox.FilterBatchesProved(opts)
	if err != nil {
		return err
	}
	defer provedIter.Close()
	for provedIter.Next() {
		e := provedIter.Event
		p.withRetry(func() error { return p.eventHandlers.batchesProvedHandler.HandlePacaya(ctx, e) })
	}
	if err := provedIter.Error(); err != nil {
		return err
	}

	shastaProvedIter, err := p.rpc.ShastaClients.Inbox.FilterProved(opts, nil)
	if err != nil {
		return err
	}
	defer shastaProvedIter.Close()
	for shastaProvedIter.Next() {
		e := shastaProvedIter.Event
		p.withRetry(func() error { return p.eventHandlers.batchesProvedHandler.HandleShasta(ctx, e) })
	}
	if err := shastaProvedIter.Error(); err != nil {
		return err
	}

	return nil
}

// proveOp iterates through BatchProposed events.
func (p *Prover) proveOp() error {
	iter, err := eventIterator.NewBatchProposedIterator(p.ctx, &eventIterator.BatchProposedIteratorConfig{
		RpcClient:            p.rpc,
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

// aggregateOp aggregates all proofs in buffer.
func (p *Prover) aggregateOp(proofType proofProducer.ProofType, isShasta bool) error {
	var err error
	if isShasta {
		err = p.proofSubmitterShasta.AggregateProofsByType(p.ctx, proofType)
	} else {
		err = p.proofSubmitterPacaya.AggregateProofsByType(p.ctx, proofType)
	}
	if err != nil {
		log.Error("Failed to aggregate proofs", "error", err, "proofType", proofType)
		return err
	}
	return nil
}

// requestProofOp requests a new proof generation operation.
func (p *Prover) requestProofOp(meta metadata.TaikoProposalMetaData) error {
	if meta.IsShasta() {
		return p.proofSubmitterShasta.RequestProof(p.ctx, meta)
	}
	if err := p.proofSubmitterPacaya.RequestProof(p.ctx, meta); err != nil {
		log.Error("Request new batch proof error", "batchID", meta.Pacaya().GetBatchID(), "error", err)
		return err
	}

	return nil
}

// submitProofAggregationOp performs a batch proof submission operation.
func (p *Prover) submitProofAggregationOp(batchProof *proofProducer.BatchProofs) error {
	if batchProof == nil || len(batchProof.ProofResponses) == 0 {
		return fmt.Errorf("empty batch proof")
	}
	submitter := p.proofSubmitterPacaya
	if batchProof.ProofResponses[0].Meta.IsShasta() {
		submitter = p.proofSubmitterShasta
	}
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
		// Create a fresh, per-call backoff policy to avoid shared state across goroutines.
		bo := backoff.WithContext(
			backoff.WithMaxRetries(
				backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval),
				p.cfg.BackOffMaxRetries,
			),
			p.ctx,
		)
		if err := backoff.Retry(f, bo); err != nil {
			log.Error("Operation failed", "error", err)
		}
	}()
}
