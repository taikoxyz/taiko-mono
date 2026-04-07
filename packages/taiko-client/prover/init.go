package prover

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"

	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// initProofSubmitter initializes the proof submitter from the non-zero verifier addresses set in protocol.
func (p *Prover) initProofSubmitter(ctx context.Context, txBuilder *transaction.ProveBatchesTxBuilder) error {
	var (
		// ZKVM proof producers.
		zkvmProducer producer.ProofProducer

		// All activated proof types in protocol.
		proofTypes = make([]producer.ProofType, 0, proofSubmitter.MaxNumSupportedProofTypes)

		// VerifierIDs
		sgxGethVerifierID   uint8 = 1
		sgxRethVerifierID   uint8 = 4
		risc0RethVerifierID uint8 = 5
		sp1RethVerifierID   uint8 = 6

		err error
	)

	sgxGethProducer := &producer.SgxGethProofProducer{
		RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
		VerifierID:          sgxGethVerifierID,
		ApiKey:              p.cfg.RaikoApiKey,
		RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		Dummy:               p.cfg.Dummy,
	}
	// Initialize the sgx proof producer.
	proofTypes = append(proofTypes, producer.ProofTypeSgx)
	sgxRethProducer := &producer.ComposeProofProducer{
		SgxGethProducer: sgxGethProducer,
		VerifierIDs: map[producer.ProofType]uint8{
			producer.ProofTypeSgx: sgxRethVerifierID,
		},
		RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
		ProofType:           producer.ProofTypeSgx,
		ApiKey:              p.cfg.RaikoApiKey,
		RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		Dummy:               p.cfg.Dummy,
	}

	// Initialize the zk verifiers and zkvm proof producers.
	var zkVerifierIDs = make(map[producer.ProofType]uint8, proofSubmitter.MaxNumSupportedZkTypes)
	proofTypes = append(proofTypes, producer.ProofTypeZKR0)
	zkVerifierIDs[producer.ProofTypeZKR0] = risc0RethVerifierID
	proofTypes = append(proofTypes, producer.ProofTypeZKSP1)
	zkVerifierIDs[producer.ProofTypeZKSP1] = sp1RethVerifierID

	if len(p.cfg.RaikoZKVMHostEndpoint) != 0 {
		zkvmProducer = &producer.ComposeProofProducer{
			VerifierIDs:         zkVerifierIDs,
			SgxGethProducer:     sgxGethProducer,
			RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
			ApiKey:              p.cfg.RaikoApiKey,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			ProofType:           producer.ProofTypeZKAny,
			Dummy:               p.cfg.Dummy,
		}
	}
	// Init proof buffers.
	var (
		proofBuffers = make(map[producer.ProofType]*producer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
		cacheMaps    = make(
			map[producer.ProofType]cmap.ConcurrentMap[string, *producer.ProofResponse],
			proofSubmitter.MaxNumSupportedProofTypes,
		)
	)
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	for _, proofType := range proofTypes {
		cacheMaps[proofType] = cmap.New[*producer.ProofResponse]()
		switch proofType {
		case producer.ProofTypeOp, producer.ProofTypeSgx:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.SGXProofBufferSize)
		case producer.ProofTypeZKR0, producer.ProofTypeZKSP1:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.ZKVMProofBufferSize)
		default:
			return fmt.Errorf("unexpected proof type: %s", proofType)
		}
	}

	if p.proofSubmitter, err = proofSubmitter.NewProofSubmitter(
		p.ctx,
		sgxRethProducer,
		zkvmProducer,
		p.batchProofGenerationCh,
		p.batchesAggregationNotify,
		p.proofSubmissionCh,
		&proofSubmitter.SenderOptions{
			RPCClient:    p.rpc,
			Txmgr:        p.txmgr,
			PrivateTxmgr: p.privateTxmgr,
			GasLimit:     p.cfg.ProveBatchesGasLimit,
		},
		txBuilder,
		p.cfg.ProofPollingInterval,
		proofBuffers,
		p.cfg.ForceBatchProvingInterval,
		cacheMaps,
		p.flushCacheNotify,
		new(big.Int).SetUint64(p.cfg.ProposalWindowSize),
	); err != nil {
		return fmt.Errorf("failed to initialize proof submitter: %w", err)
	}

	return nil
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingProposalID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	coreState, err := p.rpc.GetCoreState(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta core state: %w", err)
	}
	if startingProposalID == nil {
		startingProposalID = coreState.LastFinalizedProposalId
	}

	if startingProposalID.Cmp(coreState.NextProposalId) >= 0 {
		log.Warn(
			"Provided startingProposalID is greater than the last proposal ID, using last finalized proposal ID instead",
			"providedStartingProposalID", startingProposalID,
			"nextProposalId", coreState.NextProposalId,
		)
		startingProposalID = coreState.LastFinalizedProposalId
	}
	if startingProposalID.Cmp(coreState.LastFinalizedProposalId) < 0 {
		log.Warn(
			"Provided startingProposalID is less than the last finalized proposal ID, using last finalized proposal ID instead",
			"providedStartingProposalID", startingProposalID,
			"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
		)
		startingProposalID = coreState.LastFinalizedProposalId
	}

	log.Info("Init L1Current cursor for Shasta protocol", "startingProposalID", startingProposalID)

	if startingProposalID.Cmp(common.Big0) == 0 {
		l1Current, err := p.rpc.GetGenesisL1Header(p.ctx)
		if err != nil {
			return fmt.Errorf("failed to get Shasta activation header: %w", err)
		}
		p.sharedState.SetL1Current(l1Current)
		return nil
	}

	_, eventLog, err := p.rpc.GetProposalByID(p.ctx, startingProposalID)
	if err != nil {
		return fmt.Errorf("failed to get proposal by ID %d: %w", startingProposalID, err)
	}
	l1Current, err := p.rpc.L1.HeaderByHash(p.ctx, eventLog.BlockHash)
	if err != nil {
		return err
	}
	p.sharedState.SetL1Current(l1Current)
	return nil
}

// initEventHandlers initialize all event handlers which will be used by the current prover.
func (p *Prover) initEventHandlers() error {
	p.eventHandlers = &eventHandlers{}
	// ------- Proposal -------
	opts := &handler.NewProposalEventHandlerOps{
		SharedState:              p.sharedState,
		ProverAddress:            p.ProverAddress(),
		RPC:                      p.rpc,
		LocalProposerAddresses:   p.cfg.LocalProposerAddresses,
		AssignmentExpiredCh:      p.assignmentExpiredCh,
		ProofSubmissionCh:        p.proofSubmissionCh,
		BackOffRetryInterval:     p.cfg.BackOffRetryInterval,
		BackOffMaxRetries:        p.cfg.BackOffMaxRetries,
		ProveUnassignedProposals: p.cfg.ProveUnassignedProposals,
	}
	p.eventHandlers.proposalHandler = handler.NewProposalEventHandler(opts)
	// ------- ProofsReceived -------
	p.eventHandlers.proofsReceivedHandler = handler.NewProofsReceivedEventHandler(p.rpc)
	// ------- AssignmentExpired -------
	p.eventHandlers.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
		p.rpc,
		p.proofSubmissionCh,
	)

	return nil
}
