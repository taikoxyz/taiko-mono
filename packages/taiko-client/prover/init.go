package prover

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// setApprovalAmount will set the allowance on the TaikoToken contract for the
// configured proverAddress as owner and the contract as spender,
// if `--prover.allowance` flag is provided for allowance.
func (p *Prover) setApprovalAmount(ctx context.Context, contract common.Address) error {
	// Skip setting approval amount if `--prover.allowance` flag is not set.
	if p.cfg.Allowance == nil || p.cfg.Allowance.Cmp(common.Big0) != 1 {
		log.Info("Skipping setting approval, `--prover.allowance` flag not set")
		return nil
	}

	// Check the existing allowance for the contract.
	allowance, err := p.rpc.L1Contracts.TaikoToken.Allowance(&bind.CallOpts{Context: ctx}, p.ProverAddress(), contract)
	if err != nil {
		return err
	}

	log.Info("Existing allowance for the contract", "allowance", utils.WeiToEther(allowance), "contract", contract)

	// If the existing allowance is greater or equal to the configured allowance, skip setting allowance.
	if allowance.Cmp(p.cfg.Allowance) >= 0 {
		log.Info(
			"Skipping setting allowance, allowance already greater or equal",
			"allowance", utils.WeiToEther(allowance),
			"approvalAmount", p.cfg.Allowance,
			"contract", contract,
		)
		return nil
	}

	log.Info("Approving the contract for taiko token", "allowance", p.cfg.Allowance, "contract", contract)
	data, err := encoding.TaikoTokenABI.Pack("approve", contract, p.cfg.Allowance)
	if err != nil {
		return err
	}

	receipt, err := p.txmgr.Send(ctx, txmgr.TxCandidate{TxData: data, To: &p.cfg.TaikoTokenAddress})
	if err != nil {
		return err
	}
	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to approve allowance for contract (%s): %s", contract, receipt.TxHash.Hex())
	}

	log.Info("Approved the contract for taiko token", "txHash", receipt.TxHash.Hex(), "contract", contract)

	// Check the new allowance for the contract.
	if allowance, err = p.rpc.L1Contracts.TaikoToken.Allowance(
		&bind.CallOpts{Context: ctx},
		p.ProverAddress(),
		contract,
	); err != nil {
		return err
	}

	log.Info("New allowance for the contract", "allowance", utils.WeiToEther(allowance), "contract", contract)

	return nil
}

// initShastaProofSubmitter initializes the proof submitter from the non-zero verifier addresses set in protocol.
func (p *Prover) initShastaProofSubmitter(ctx context.Context, txBuilder *transaction.ProveBatchesTxBuilder) error {
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

	if p.proofSubmitterShasta, err = proofSubmitter.NewProofSubmitterShasta(
		p.ctx,
		sgxRethProducer,
		zkvmProducer,
		p.batchProofGenerationCh,
		p.batchesAggregationNotifyShasta,
		p.proofSubmissionCh,
		&proofSubmitter.SenderOptions{
			RPCClient:        p.rpc,
			Txmgr:            p.txmgr,
			PrivateTxmgr:     p.privateTxmgr,
			ProverSetAddress: p.cfg.ProverSetAddress,
			GasLimit:         p.cfg.ProveBatchesGasLimit,
		},
		txBuilder,
		p.cfg.ProofPollingInterval,
		proofBuffers,
		p.cfg.ForceBatchProvingInterval,
		cacheMaps,
		p.flushCacheNotify,
		new(big.Int).SetUint64(p.cfg.ProposalWindowSize),
	); err != nil {
		return fmt.Errorf("failed to initialize Shasta proof submitter: %w", err)
	}

	return nil
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBatchID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	return p.initL1CurrentShasta(startingBatchID)
}

// initL1CurrentShasta initializes prover's L1Current cursor for Shasta protocol.
func (p *Prover) initL1CurrentShasta(startingBatchID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	coreState, err := p.rpc.GetCoreStateShasta(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta core state: %w", err)
	}
	if startingBatchID == nil {
		startingBatchID = coreState.LastFinalizedProposalId
	}

	if startingBatchID.Cmp(coreState.NextProposalId) >= 0 {
		log.Warn(
			"Provided startingBatchID is greater than the last proposal ID, using last finalized proposal ID instead",
			"providedStartingBatchID", startingBatchID,
			"nextProposalId", coreState.NextProposalId,
		)
		startingBatchID = coreState.LastFinalizedProposalId
	}
	if startingBatchID.Cmp(coreState.LastFinalizedProposalId) < 0 {
		log.Warn(
			"Provided startingBatchID is less than the last finalized proposal ID, using last finalized proposal ID instead",
			"providedStartingBatchID", startingBatchID,
			"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
		)
		startingBatchID = coreState.LastFinalizedProposalId
	}

	log.Info("Init L1Current cursor for Shasta protocol", "startingBatchID", startingBatchID)

	_, eventLog, err := p.rpc.GetProposalByIDShasta(p.ctx, startingBatchID)
	if err != nil {
		return fmt.Errorf("failed to get proposal by ID %d: %w", startingBatchID, err)
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
	// ------- BatchProposed -------
	opts := &handler.NewBatchProposedEventHandlerOps{
		SharedState:            p.sharedState,
		ProverAddress:          p.ProverAddress(),
		ProverSetAddress:       p.cfg.ProverSetAddress,
		RPC:                    p.rpc,
		LocalProposerAddresses: p.cfg.LocalProposerAddresses,
		AssignmentExpiredCh:    p.assignmentExpiredCh,
		ProofSubmissionCh:      p.proofSubmissionCh,
		BackOffRetryInterval:   p.cfg.BackOffRetryInterval,
		BackOffMaxRetries:      p.cfg.BackOffMaxRetries,
		ProveUnassignedBlocks:  p.cfg.ProveUnassignedBlocks,
	}
	p.eventHandlers.batchProposedHandler = handler.NewBatchProposedEventHandler(opts)
	// ------- BatchesProved -------
	p.eventHandlers.batchesProvedHandler = handler.NewBatchesProvedEventHandler(p.rpc)
	// ------- AssignmentExpired -------
	p.eventHandlers.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
		p.rpc,
		p.proofSubmissionCh,
	)

	return nil
}
