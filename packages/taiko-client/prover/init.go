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
				bufferSize    = p.cfg.SGXProofBufferSize
				proofProducer producer.ProofProducer
				submitter     proofSubmitter.Submitter
				err           error
			)
			switch tier.ID {
			case encoding.TierOptimisticID:
				proofProducer = &producer.OptimisticProofProducer{}
			case encoding.TierSgxID:
				proofProducer = &producer.SGXProofProducer{
					RaikoHostEndpoint:   p.cfg.RaikoHostEndpoint,
					JWT:                 p.cfg.RaikoJWT,
					ProofType:           producer.ProofTypeSgx,
					RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
					Dummy:               p.cfg.Dummy,
				}
			case encoding.TierZkVMRisc0ID:
				continue
			case encoding.TierZkVMSp1ID:
				proofProducer = &producer.ZKvmProofProducer{
					RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
					JWT:                 p.cfg.RaikoJWT,
					RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
					Dummy:               p.cfg.Dummy,
				}
				// Since the proof aggregation in Ontake fork is selected by request tier, and
				// sp1 & risc0 can't be aggregated together, we disabled the proof aggregation until the Pacaya fork
				bufferSize = 1
			case encoding.TierGuardianMinorityID:
				proofProducer = producer.NewGuardianProofProducer(encoding.TierGuardianMinorityID, p.cfg.EnableLivenessBondProof)
				// For guardian, we need to prove the unsigned block as soon as possible
				bufferSize = 1
			case encoding.TierGuardianMajorityID:
				proofProducer = producer.NewGuardianProofProducer(encoding.TierGuardianMajorityID, p.cfg.EnableLivenessBondProof)
				// For guardian, we need to prove the unsigned block as soon as possible
				bufferSize = 1
			default:
				return fmt.Errorf("unsupported tier: %d", tier.ID)
			}

			if submitter, err = proofSubmitter.NewProofSubmitterOntake(
				p.rpc,
				proofProducer,
				p.proofGenerationCh,
				p.batchProofGenerationCh,
				p.aggregationNotify,
				p.proofSubmissionCh,
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
				p.cfg.ProofPollingInterval,
			); err != nil {
				return err
			}

			p.proofSubmittersOntake = append(p.proofSubmittersOntake, submitter)
		}
	}
	return p.initPacayaProofSubmitter(txBuilder)
}

// initPacayaProofSubmitter initializes the proof submitter from the non-zero verifier addresses set in protocol.
func (p *Prover) initPacayaProofSubmitter(txBuilder *transaction.ProveBlockTxBuilder) error {
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
		JWT:                 p.cfg.RaikoJWT,
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
		proofTypes = append(proofTypes, producer.ProofTypeBoundless)
		zkVerifiers[producer.ProofTypeZKR0] = risc0VerifierAddress
		// Note: ProofTypeBoundless will use the same verifier contract as the ProofTypeZKR0
		zkVerifiers[producer.ProofTypeBoundless] = risc0VerifierAddress
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
			JWT:                 p.cfg.RaikoJWT,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			ProofType:           producer.ProofTypeZKAny,
			Dummy:               p.cfg.Dummy,
		}
	}

	// Init proof buffers for Pacaya.
	var proofBuffers = make(map[producer.ProofType]*producer.ProofBuffer, proofSubmitter.MaxNumSupportedProofTypes)
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	for _, proofType := range proofTypes {
		switch proofType {
		case producer.ProofTypeOp, producer.ProofTypeSgx:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.SGXProofBufferSize)
		case producer.ProofTypeZKR0, producer.ProofTypeZKSP1, producer.ProofTypeBoundless:
			proofBuffers[proofType] = producer.NewProofBuffer(p.cfg.ZKVMProofBufferSize)
		default:
			return fmt.Errorf("unexpected proof type: %s", proofType)
		}
	}

	if p.proofSubmitterPacaya, err = proofSubmitter.NewProofSubmitterPacaya(
		p.rpc,
		baseLevelProofProducer,
		zkvmProducer,
		p.proofGenerationCh,
		p.batchProofGenerationCh,
		p.aggregationNotify,
		p.batchesAggregationNotify,
		p.proofSubmissionCh,
		p.cfg.ProverSetAddress,
		p.cfg.TaikoL2Address,
		p.cfg.ProveBlockGasLimit,
		p.txmgr,
		p.privateTxmgr,
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
			JWT:                 p.cfg.RaikoJWT,
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
				JWT:                 p.cfg.RaikoJWT,
				Dummy:               true,
				RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			}, nil
		}
	}
	// If no base level prover found, return an error.
	return "", nil, fmt.Errorf("no proving base level prover found")
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
			if startingBlockID.Uint64() < p.rpc.PacayaClients.ForkHeight {
				blockInfo, err := p.rpc.GetL2BlockInfoV2(p.ctx, startingBlockID)
				if err != nil {
					return fmt.Errorf("failed to get block info for blockID: %d", startingBlockID)
				}

				l1Head, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(blockInfo.ProposedIn))
				if err != nil {
					return fmt.Errorf("failed to get L1 head for blockID: %d", blockInfo.ProposedIn)
				}
				p.sharedState.SetL1Current(l1Head)
				return nil
			} else {
				batch, err := p.rpc.GetBatchByID(p.ctx, startingBlockID)
				if err != nil {
					return fmt.Errorf("failed to get batch by ID: %d", startingBlockID)
				}

				l1Head, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(batch.AnchorBlockId))
				if err != nil {
					return fmt.Errorf("failed to get L1 head for blockID: %d", batch.AnchorBlockId)
				}
				p.sharedState.SetL1Current(l1Head)
				return nil
			}
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
		p.eventHandlers.blockVerifiedHandler = handler.NewBlockVerifiedEventHandler(p.rpc, common.Address{})
		return nil
	}
	p.eventHandlers.blockVerifiedHandler = handler.NewBlockVerifiedEventHandler(p.rpc, guardianProverAddress)

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
