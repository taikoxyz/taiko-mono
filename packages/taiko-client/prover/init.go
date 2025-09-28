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

	// Skip setting allowance if taiko token contract is not found.
	if p.rpc.PacayaClients.TaikoToken == nil {
		log.Info("Skipping setting allowance, taiko token contract not found")
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

// initPacayaProofSubmitter initializes the proof submitter from the non-zero verifier addresses set in protocol.
func (p *Prover) initPacayaProofSubmitter(txBuilder *transaction.ProveBatchesTxBuilder) error {
	var (
		// A single proof producer -- unlike upstream taiko-client
		proofProducer producer.ProofProducer

		// Proof verifiers addresses.
		sgxGethVerifierAddress common.Address
		sgxRethVerifierAddress common.Address
		risc0VerifierAddress   common.Address
		sp1VerifierAddress     common.Address

		// All activated proof types in protocol.
		proofTypes = make([]producer.ProofType, 0, proofSubmitter.MaxNumSupportedProofTypes)
		verifiers  = make(map[producer.ProofType]common.Address, proofSubmitter.MaxNumSupportedProofTypes)

		err error
	)

	// Get the sgx geth verifier address from the protocol
	if sgxGethVerifierAddress, err = p.rpc.GetSGXGethVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get sgx geth verifier: %w", err)
	}
	if sgxGethVerifierAddress != rpc.ZeroAddress {
		verifiers[producer.ProofTypeSgxGeth] = sgxGethVerifierAddress
	}

	// Get the sgx reth verifier address from the protocol
	if sgxRethVerifierAddress, err = p.rpc.GetSGXRethVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get sgx verifier: %w", err)
	}
	if sgxRethVerifierAddress != rpc.ZeroAddress {
		verifiers[producer.ProofTypeSgx] = sgxRethVerifierAddress
	}

	if len(verifiers) == 0 {
		return fmt.Errorf("at least one of the sgx verifiers (sgx geth, sgx reth) must be set")
	}

	// Initialize the zk verifiers and zkvm proof producers
	if risc0VerifierAddress, err = p.rpc.GetRISC0VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get risc0 verifier: %w", err)
	}
	if risc0VerifierAddress != rpc.ZeroAddress {
		proofTypes = append(proofTypes, producer.ProofTypeZKR0)
		verifiers[producer.ProofTypeZKR0] = risc0VerifierAddress
	}
	if sp1VerifierAddress, err = p.rpc.GetSP1VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return fmt.Errorf("failed to get sp1 verifier: %w", err)
	}
	if sp1VerifierAddress != rpc.ZeroAddress {
		proofTypes = append(proofTypes, producer.ProofTypeZKSP1)
		verifiers[producer.ProofTypeZKSP1] = sp1VerifierAddress
	}

	if verifiers[producer.ProofTypeZKR0] == rpc.ZeroAddress && verifiers[producer.ProofTypeZKSP1] == rpc.ZeroAddress {
		return fmt.Errorf("at least one of the zk verifiers (risc0, sp1) must be set")
	}

	proofProducer = &producer.ComposeProofProducer{
		Verifiers:             verifiers,
		RaikoSGXHostEndpoint:  p.cfg.RaikoSGXHostEndpoint,  // used for sgx geth + sgx reth
		RaikoZKVMHostEndpoint: p.cfg.RaikoZKVMHostEndpoint, // used for risc0 + sp1
		JWT:                   p.cfg.RaikoJWT,
		RaikoRequestTimeout:   p.cfg.RaikoRequestTimeout,
		Dummy:                 p.cfg.Dummy,
	}

	log.Info("Initialize prover", "proofProducer", proofProducer)

	// Init proof buffers.
	var proofBuffers = make(map[producer.ProofType]*producer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	for _, proofType := range proofTypes {
		switch proofType {
		case producer.ProofTypeZKR0, producer.ProofTypeZKSP1: // only for risc0 + sp1 by design
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.ZKVMProofBufferSize)
		default:
			return fmt.Errorf("unexpected proof type: %s", proofType)
		}
	}

	if p.proofSubmitterPacaya, err = proofSubmitter.NewProofSubmitterPacaya(
		proofProducer,
		p.batchProofGenerationCh,
		p.batchesAggregationNotify,
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

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBatchID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

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

	latestVerifiedHeaderL1Origin, err := p.rpc.L2.L1OriginByID(p.ctx, startingBatchID)
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			batch, err := p.rpc.GetBatchByID(p.ctx, startingBatchID)
			if err != nil {
				return fmt.Errorf("failed to get batch by ID: %d", startingBatchID)
			}

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

// initEventHandlers initialize all event handlers which will be used by the current prover.
func (p *Prover) initEventHandlers() error {
	p.eventHandlers = &eventHandlers{}
	// ------- BatchProposed -------
	opts := &handler.NewBatchProposedEventHandlerOps{
		SharedState:                 p.sharedState,
		ProverAddress:               p.ProverAddress(),
		ProverSetAddress:            p.cfg.ProverSetAddress,
		SurgeProposerWrapperAddress: p.cfg.SurgeProposerWrapperAddress,
		RPC:                         p.rpc,
		LocalProposerAddresses:      p.cfg.LocalProposerAddresses,
		AssignmentExpiredCh:         p.assignmentExpiredCh,
		ProofSubmissionCh:           p.proofSubmissionCh,
		BackOffRetryInterval:        p.cfg.BackOffRetryInterval,
		BackOffMaxRetrys:            p.cfg.BackOffMaxRetries,
		ProveUnassignedBlocks:       p.cfg.ProveUnassignedBlocks,
	}
	p.eventHandlers.batchProposedHandler = handler.NewBatchProposedEventHandler(opts)
	// ------- BatchesProved -------
	p.eventHandlers.batchesProvedHandler = handler.NewBatchesProvedEventHandler(
		p.rpc,
		p.proofSubmissionCh,
	)
	// ------- BatchesRollbacked -------
	p.eventHandlers.batchesRollbackedHandler = handler.NewBatchesRollbackedEventHandler(
		&handler.NewBatchesRollbackedEventHandlerOps{
			SharedState: p.sharedState,
		},
	)
	// ------- AssignmentExpired -------
	p.eventHandlers.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
		p.rpc,
		p.ProverAddress(),
		p.cfg.ProverSetAddress,
		p.proofSubmissionCh,
	)
	// ------- BatchesVerified -------
	p.eventHandlers.batchesVerifiedHandler = handler.NewBatchesVerifiedEventHandler(p.rpc)

	return nil
}
