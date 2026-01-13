package prover

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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
	allowance, err := p.rpc.PacayaClients.TaikoToken.Allowance(&bind.CallOpts{Context: ctx}, p.ProverAddress(), contract)
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
	if allowance, err = p.rpc.PacayaClients.TaikoToken.Allowance(
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
	var proofBuffers = make(map[producer.ProofType]*producer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	for _, proofType := range proofTypes {
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
	); err != nil {
		return fmt.Errorf("failed to initialize Shasta proof submitter: %w", err)
	}

	return nil
}

// initPacayaProofSubmitter initializes the proof submitter from the non-zero verifier addresses set in protocol.
func (p *Prover) initPacayaProofSubmitter(txBuilder *transaction.ProveBatchesTxBuilder) error {
	var (
		// Proof producers.
		baseLevelProofType     producer.ProofType
		baseLevelProofProducer producer.ProofProducer

		// ZKVM proof producers.
		zkvmProducer producer.ProofProducer

		// Proof verifiers addresses.
		sgxGethVerifierAddress common.Address
		risc0VerifierAddress   common.Address
		sp1VerifierAddress     common.Address

		// All activated proof types in protocol.
		proofTypes = make([]producer.ProofType, 0, proofSubmitter.MaxNumSupportedProofTypes)

		err error
	)

	// Get the required sgx geth verifier address from the protocol, and initialize the sgx geth producer.
	if sgxGethVerifierAddress, err = p.rpc.GetSgxGethVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get sgx geth verifier: %w", err)
	}
	if sgxGethVerifierAddress == rpc.ZeroAddress {
		return fmt.Errorf("sgx geth verifier not found")
	}
	sgxGethProducer := &producer.SgxGethProofProducer{
		Verifier:            sgxGethVerifierAddress,
		RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
		ApiKey:              p.cfg.RaikoApiKey,
		RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		Dummy:               p.cfg.Dummy,
	}

	// Initialize the base level prover.
	if baseLevelProofType, baseLevelProofProducer, err = p.initBaseLevelProofProducerPacaya(sgxGethProducer); err != nil {
		return fmt.Errorf("failed to initialize base level prover: %w", err)
	}
	proofTypes = append(proofTypes, baseLevelProofType)

	// Initialize the zk verifiers and zkvm proof producers.
	var zkVerifiers = make(map[producer.ProofType]common.Address, proofSubmitter.MaxNumSupportedZkTypes)
	if risc0VerifierAddress, err = p.rpc.GetRISC0VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get risc0 verifier: %w", err)
	}
	if risc0VerifierAddress != rpc.ZeroAddress {
		proofTypes = append(proofTypes, producer.ProofTypeZKR0)
		zkVerifiers[producer.ProofTypeZKR0] = risc0VerifierAddress
	}
	if sp1VerifierAddress, err = p.rpc.GetSP1VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get sp1 verifier: %w", err)
	}
	if sp1VerifierAddress != rpc.ZeroAddress {
		proofTypes = append(proofTypes, producer.ProofTypeZKSP1)
		zkVerifiers[producer.ProofTypeZKSP1] = sp1VerifierAddress
	}
	if len(p.cfg.RaikoZKVMHostEndpoint) != 0 && len(zkVerifiers) > 0 {
		zkvmProducer = &producer.ComposeProofProducer{
			Verifiers:           zkVerifiers,
			SgxGethProducer:     sgxGethProducer,
			RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
			ApiKey:              p.cfg.RaikoApiKey,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			ProofType:           producer.ProofTypeZKAny,
			Dummy:               p.cfg.Dummy,
		}
	}

	// Init proof buffers.
	var proofBuffers = make(map[producer.ProofType]*producer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	for _, proofType := range proofTypes {
		switch proofType {
		case producer.ProofTypeOp, producer.ProofTypeSgx:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.SGXProofBufferSize)
		case producer.ProofTypeZKR0, producer.ProofTypeZKSP1:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.ZKVMProofBufferSize)
		default:
			return fmt.Errorf("unexpected proof type: %s", proofType)
		}
	}

	if p.proofSubmitterPacaya, err = proofSubmitter.NewProofSubmitterPacaya(
		p.ctx,
		baseLevelProofProducer,
		zkvmProducer,
		p.batchProofGenerationCh,
		p.batchesAggregationNotifyPacaya,
		p.proofSubmissionCh,
		p.cfg.TaikoAnchorAddress,
		&proofSubmitter.SenderOptions{
			RPCClient:        p.rpc,
			Txmgr:            p.txmgr,
			PrivateTxmgr:     p.privateTxmgr,
			ProverSetAddress: p.cfg.ProverSetAddress,
			GasLimit:         p.cfg.ProveBatchesGasLimit,
		},
		txBuilder,
		proofBuffers,
		p.cfg.ForceBatchProvingInterval,
		p.cfg.ProofPollingInterval,
	); err != nil {
		return fmt.Errorf("failed to initialize Pacaya proof submitter: %w", err)
	}
	return nil
}

// initBaseLevelProofProducerPacaya fetches the SGX / OP verifier addresses from the protocol, if the verifier exists,
// then initialize the corresponding base level proof producers.
func (p *Prover) initBaseLevelProofProducerPacaya(sgxGethProducer *producer.SgxGethProofProducer) (
	producer.ProofType,
	producer.ProofProducer,
	error,
) {
	var (
		// Proof verifiers addresses
		opVerifierAddress  common.Address
		sgxVerifierAddress common.Address
		err                error
	)

	// If there is an SGX verifier, then initialize the SGX prover as the base level prover.
	if sgxVerifierAddress, err = p.rpc.GetSGXVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return "", nil, fmt.Errorf("failed to get sgx verifier: %w", err)
	}
	if sgxVerifierAddress != rpc.ZeroAddress {
		log.Info("Initialize baseLevelProver", "type", producer.ProofTypeSgx, "verifier", sgxVerifierAddress)

		return producer.ProofTypeSgx, &producer.ComposeProofProducer{
			SgxGethProducer:     sgxGethProducer,
			Verifiers:           map[producer.ProofType]common.Address{producer.ProofTypeSgx: sgxVerifierAddress},
			RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
			ProofType:           producer.ProofTypeSgx,
			ApiKey:              p.cfg.RaikoApiKey,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			Dummy:               p.cfg.Dummy,
		}, nil
	} else {
		// If there is no SGX verifier, then try to get the OP verifier address, and initialize
		// the OP prover as the base level prover.
		if opVerifierAddress, err = p.rpc.GetOPVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
			return "", nil, fmt.Errorf("failed to get op verifier address: %w", err)
		}
		if opVerifierAddress != rpc.ZeroAddress {
			log.Info("Initialize baseLevelProver", "type", producer.ProofTypeOp, "verifier", opVerifierAddress)

			return producer.ProofTypeOp, &producer.ComposeProofProducer{
				SgxGethProducer:     sgxGethProducer,
				Verifiers:           map[producer.ProofType]common.Address{producer.ProofTypeOp: opVerifierAddress},
				RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
				ProofType:           producer.ProofTypeOp,
				ApiKey:              p.cfg.RaikoApiKey,
				Dummy:               true,
				RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			}, nil
		}
	}
	// If no base level prover found, return an error.
	return "", nil, fmt.Errorf("no proving base level prover found")
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBatchID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	// Try to initialize L1Current cursor for Shasta protocol first.
	if err := p.initL1CurrentShasta(startingBatchID); err == nil {
		return nil
	}

	// If failed, then try to initialize L1Current cursor for Pacaya protocol.
	if startingBatchID == nil {
		var (
			lastVerifiedBatchID *big.Int
			genesisHeight       *big.Int
		)
		stateVars, err := p.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: p.ctx})
		if err != nil {
			return err
		}
		lastVerifiedBatchID = new(big.Int).SetUint64(stateVars.Stats2.LastVerifiedBatchId)
		genesisHeight = new(big.Int).SetUint64(stateVars.Stats1.GenesisHeight)

		if lastVerifiedBatchID.Cmp(common.Big0) == 0 {
			genesisL1Header, err := p.rpc.L1.HeaderByNumber(p.ctx, genesisHeight)
			if err != nil {
				return err
			}

			p.sharedState.SetL1Current(genesisL1Header)
			return nil
		}

		startingBatchID = lastVerifiedBatchID
	}

	log.Info("Init L1Current cursor", "startingBatchID", startingBatchID)

	batch, err := p.rpc.GetBatchByID(p.ctx, startingBatchID)
	if err != nil {
		return fmt.Errorf("failed to get batch by ID: %d", startingBatchID)
	}
	latestVerifiedHeaderL1Origin, err := p.rpc.L2.L1OriginByID(p.ctx, new(big.Int).SetUint64(batch.LastBlockId))
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			l1Head, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(batch.AnchorBlockId))
			if err != nil {
				return fmt.Errorf("failed to get L1 head for blockID: %d", batch.AnchorBlockId)
			}
			p.sharedState.SetL1Current(l1Head)
			return nil
		}
		return err
	}

	l1Current, err := p.rpc.L1.HeaderByHash(p.ctx, latestVerifiedHeaderL1Origin.L1BlockHash)
	if err != nil {
		return err
	}
	p.sharedState.SetL1Current(l1Current)

	return nil
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
		return fmt.Errorf("failed to get proposal by ID: %d", startingBatchID)
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
	p.eventHandlers.batchesProvedHandler = handler.NewBatchesProvedEventHandler(
		p.rpc,
		p.proofSubmissionCh,
	)
	// ------- AssignmentExpired -------
	p.eventHandlers.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
		p.rpc,
		p.proofSubmissionCh,
	)
	// ------- BatchesVerified -------
	p.eventHandlers.batchesVerifiedHandler = handler.NewBatchesVerifiedEventHandler(p.rpc)

	return nil
}
