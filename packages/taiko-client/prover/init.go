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
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
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
	allowance, err := p.rpc.PacayaClients.TaikoToken.Allowance(
		&bind.CallOpts{Context: ctx},
		p.ProverAddress(),
		contract,
	)
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

	receipt, err := p.txmgr.Send(ctx, txmgr.TxCandidate{
		TxData: data,
		To:     &p.cfg.TaikoTokenAddress,
	})
	if err != nil {
		return err
	}
	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to approve allowance for contract (%s): %s", contract, receipt.TxHash.Hex())
	}

	log.Info(
		"Approved the contract for taiko token",
		"txHash", receipt.TxHash.Hex(),
		"contract", contract,
	)

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

// initProofSubmitters initializes the proof submitters from the given tiers in protocol.
func (p *Prover) initProofSubmitters(
	txBuilder *transaction.ProveBlockTxBuilder,
	tiers []*rpc.TierProviderTierWithID,
) (err error) {
	if len(tiers) > 0 {
		for _, tier := range p.sharedState.GetTiers() {
			var (
				bufferSize = p.cfg.SGXProofBufferSize
				producer   proofProducer.ProofProducer
				submitter  proofSubmitter.Submitter
				err        error
			)
			switch tier.ID {
			case encoding.TierOptimisticID:
				producer = &proofProducer.OptimisticProofProducer{}
			case encoding.TierSgxID:
				producer = &proofProducer.SGXProofProducer{
					RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
					JWT:                 p.cfg.RaikoJWT,
					ProofType:           proofProducer.ProofTypeSgx,
					Dummy:               p.cfg.Dummy,
					RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
				}
			case encoding.TierZkVMRisc0ID:
				continue
			case encoding.TierZkVMSp1ID:
				producer = &proofProducer.ZKvmProofProducer{
					RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
					JWT:                 p.cfg.RaikoJWT,
					Dummy:               p.cfg.Dummy,
					RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
				}
				bufferSize = 0
			case encoding.TierGuardianMinorityID:
				producer = proofProducer.NewGuardianProofProducer(encoding.TierGuardianMinorityID, p.cfg.EnableLivenessBondProof)
				bufferSize = 0
			case encoding.TierGuardianMajorityID:
				producer = proofProducer.NewGuardianProofProducer(encoding.TierGuardianMajorityID, p.cfg.EnableLivenessBondProof)
				bufferSize = 0
			default:
				return fmt.Errorf("unsupported tier: %d", tier.ID)
			}

			if submitter, err = proofSubmitter.NewProofSubmitterOntake(
				p.rpc,
				producer,
				p.proofGenerationCh,
				p.batchProofGenerationCh,
				p.aggregationNotify,
				p.cfg.ProverSetAddress,
				p.cfg.TaikoL2Address,
				p.cfg.Graffiti,
				p.cfg.ProveBlockGasLimit,
				p.txmgr,
				p.privateTxmgr,
				txBuilder,
				tiers,
				p.IsGuardianProver(),
				p.cfg.GuardianProofSubmissionDelay,
				bufferSize,
				p.cfg.ForceBatchProvingInterval,
			); err != nil {
				return err
			}

			p.proofSubmittersOntake = append(p.proofSubmittersOntake, submitter)
		}
	}
	return p.initPacayaProofSubmitter(txBuilder)
}

// initPacayaProofSubmitter initializes the proof submitter from the non-zero verifier addresses in protocol.
func (p *Prover) initPacayaProofSubmitter(txBuilder *transaction.ProveBlockTxBuilder) error {
	// Init verifiers for Pacaya
	var (
		baseLevelProver proofProducer.ProofProducer
		zkvmProducer    proofProducer.ProofProducer
		zkVerifiers     = make(map[string]common.Address, proofSubmitter.MaxNumSupportedZkTypes)
		proofBuffers    = make(map[string]*proofProducer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
		proofTypes      = make([]string, 0, proofSubmitter.MaxNumSupportedProofTypes)
	)
	pivotVerifier, err := p.rpc.GetPivotVerifierPacaya(&bind.CallOpts{Context: p.ctx})
	if err != nil || pivotVerifier == transaction.ZeroAddress {
		return fmt.Errorf("required pivot verifier not found: %w", err)
	}
	pivotProducer := proofProducer.PivotProofProducer{
		Verifier:            pivotVerifier,
		RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
		JWT:                 p.cfg.RaikoJWT,
		Dummy:               p.cfg.Dummy,
		RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
	}

	if opVerifier, err := p.rpc.GetOPVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return err
	} else if opVerifier != transaction.ZeroAddress {
		proofTypes = append(proofTypes, proofProducer.ProofTypeOp)
		baseLevelProver = &proofProducer.ProofProducerPacaya{
			PivotProducer: pivotProducer,
			Verifiers: map[string]common.Address{
				proofProducer.ProofTypeOp: opVerifier,
			},
			RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
			ProofType:           proofProducer.ProofTypeOp,
			JWT:                 p.cfg.RaikoJWT,
			IsOp:                true,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		}
	}
	if sgxVerifier, err := p.rpc.GetSGXVerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return err
	} else if sgxVerifier != transaction.ZeroAddress {
		proofTypes = append(proofTypes, proofProducer.ProofTypeSgx)
		baseLevelProver = &proofProducer.ProofProducerPacaya{
			PivotProducer: pivotProducer,
			Verifiers: map[string]common.Address{
				proofProducer.ProofTypeSgx: sgxVerifier,
			},
			RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
			ProofType:           proofProducer.ProofTypeSgx,
			JWT:                 p.cfg.RaikoJWT,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		}
	}

	if risc0Verifier, err := p.rpc.GetRISC0VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return err
	} else if risc0Verifier != transaction.ZeroAddress {
		proofTypes = append(proofTypes, proofProducer.ZKProofTypeR0)
		zkVerifiers[proofProducer.ZKProofTypeR0] = risc0Verifier
	}

	if sp1Verifier, err := p.rpc.GetSP1VerifierPacaya(&bind.CallOpts{Context: p.ctx}); err != nil {
		return err
	} else if sp1Verifier != transaction.ZeroAddress {
		proofTypes = append(proofTypes, proofProducer.ZKProofTypeSP1)
		zkVerifiers[proofProducer.ZKProofTypeSP1] = sp1Verifier
	}

	if len(p.cfg.RaikoZKVMHostEndpoint) != 0 && len(zkVerifiers) > 0 {
		zkvmProducer = &proofProducer.ProofProducerPacaya{
			Verifiers:           zkVerifiers,
			PivotProducer:       pivotProducer,
			RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
			JWT:                 p.cfg.RaikoJWT,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			ProofType:           proofProducer.ZKProofTypeAny,
		}
	}
	// Init proof buffers for Pacaya
	for _, proofType := range proofTypes {
		switch proofType {
		case proofProducer.ProofTypeOp, proofProducer.ProofTypeSgx:
			proofBuffers[proofType] = proofProducer.NewProofBuffer(p.cfg.SGXProofBufferSize)
		case proofProducer.ZKProofTypeR0, proofProducer.ZKProofTypeSP1:
			proofBuffers[proofType] = proofProducer.NewProofBuffer(p.cfg.ZKVMProofBufferSize)
		default:
			return fmt.Errorf("unexpected proof type: %s", proofType)
		}
	}

	if p.proofSubmitterPacaya, err = proofSubmitter.NewProofSubmitterPacaya(
		p.rpc,
		baseLevelProver,
		zkvmProducer,
		p.proofGenerationCh,
		p.batchProofGenerationCh,
		p.aggregationNotify,
		p.batchesAggregationNotify,
		p.cfg.ProverSetAddress,
		p.cfg.TaikoL2Address,
		p.cfg.ProveBlockGasLimit,
		p.txmgr,
		p.privateTxmgr,
		txBuilder,
		proofBuffers,
		p.cfg.ForceBatchProvingInterval,
	); err != nil {
		return err
	}
	return nil
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBlockID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	if startingBlockID == nil {
		var (
			lastVerifiedBlockID *big.Int
			genesisHeight       *big.Int
		)
		stateVars, err := p.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: p.ctx})
		if err != nil {
			slot1, _, err := p.rpc.GetProtocolStateVariablesOntake(&bind.CallOpts{Context: p.ctx})
			if err != nil {
				return err
			}

			lastVerifiedBlockID = new(big.Int).SetUint64(slot1.LastSyncedBlockId)
			genesisHeight = new(big.Int).SetUint64(slot1.GenesisHeight)
		} else {
			lastVerifiedBlockID = new(big.Int).SetUint64(stateVars.Stats2.LastVerifiedBatchId)
			genesisHeight = new(big.Int).SetUint64(stateVars.Stats1.GenesisHeight)
		}

		if lastVerifiedBlockID.Cmp(common.Big0) == 0 {
			genesisL1Header, err := p.rpc.L1.HeaderByNumber(p.ctx, genesisHeight)
			if err != nil {
				return err
			}

			p.sharedState.SetL1Current(genesisL1Header)
			return nil
		}

		startingBlockID = lastVerifiedBlockID
	}

	log.Info("Init L1Current cursor", "startingBlockID", startingBlockID)

	latestVerifiedHeaderL1Origin, err := p.rpc.L2.L1OriginByID(p.ctx, startingBlockID)
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			log.Warn(
				"Failed to find L1Origin for blockID, use latest L1 head instead",
				"blockID", startingBlockID,
			)
			l1Head, err := p.rpc.L1.HeaderByNumber(p.ctx, nil)
			if err != nil {
				return err
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
	// ------- BlockProposed -------
	opts := &handler.NewBlockProposedEventHandlerOps{
		SharedState:           p.sharedState,
		ProverAddress:         p.ProverAddress(),
		ProverSetAddress:      p.cfg.ProverSetAddress,
		RPC:                   p.rpc,
		ProofGenerationCh:     p.proofGenerationCh,
		AssignmentExpiredCh:   p.assignmentExpiredCh,
		ProofSubmissionCh:     p.proofSubmissionCh,
		ProofContestCh:        p.proofContestCh,
		BackOffRetryInterval:  p.cfg.BackOffRetryInterval,
		BackOffMaxRetrys:      p.cfg.BackOffMaxRetries,
		ContesterMode:         p.cfg.ContesterMode,
		ProveUnassignedBlocks: p.cfg.ProveUnassignedBlocks,
	}
	if p.IsGuardianProver() {
		p.eventHandlers.blockProposedHandler = handler.NewBlockProposedEventGuardianHandler(
			&handler.NewBlockProposedGuardianEventHandlerOps{
				NewBlockProposedEventHandlerOps: opts,
				GuardianProverHeartbeater:       p.guardianProverHeartbeater,
			},
		)
	} else {
		p.eventHandlers.blockProposedHandler = handler.NewBlockProposedEventHandler(opts)
	}
	// ------- TransitionProved -------
	p.eventHandlers.transitionProvedHandler = handler.NewTransitionProvedEventHandler(
		p.rpc,
		p.proofContestCh,
		p.proofSubmissionCh,
		p.cfg.ContesterMode,
		p.IsGuardianProver(),
	)
	// ------- TransitionContested -------
	p.eventHandlers.transitionContestedHandler = handler.NewTransitionContestedEventHandler(
		p.rpc,
		p.proofSubmissionCh,
		p.cfg.ContesterMode,
	)
	// ------- AssignmentExpired -------
	p.eventHandlers.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
		p.rpc,
		p.ProverAddress(),
		p.cfg.ProverSetAddress,
		p.proofSubmissionCh,
		p.proofContestCh,
		p.cfg.ContesterMode,
		p.IsGuardianProver(),
	)

	// ------- BlockVerified -------
	guardianProverAddress, err := p.rpc.GetGuardianProverAddress(p.ctx)
	if err != nil {
		log.Debug("Failed to get guardian prover address", "error", encoding.TryParsingCustomError(err))
		p.eventHandlers.blockVerifiedHandler = handler.NewBlockVerifiedEventHandler(common.Address{})
		return nil
	}
	p.eventHandlers.blockVerifiedHandler = handler.NewBlockVerifiedEventHandler(guardianProverAddress)

	return nil
}

// initProofTiers initializes the proof tiers for the current prover.
func (p *Prover) initProofTiers(ctx context.Context) error {
	tiers, err := p.rpc.GetTiers(ctx)
	if err != nil {
		log.Warn("Failed to get tiers", "error", err)
		return nil
	}
	p.sharedState.SetTiers(tiers)
	return nil
}
