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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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
	allowance, err := p.rpc.TaikoToken.Allowance(
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
	if allowance, err = p.rpc.TaikoToken.Allowance(
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
) error {
	for _, tier := range p.sharedState.GetTiers() {
		var (
			producer  proofProducer.ProofProducer
			submitter proofSubmitter.Submitter
			err       error
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
			producer = &proofProducer.ZKvmProofProducer{
				ZKProofType:         proofProducer.ZKProofTypeR0,
				RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
				JWT:                 p.cfg.RaikoJWT,
				Dummy:               p.cfg.Dummy,
				RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
			}
		case encoding.TierGuardianMinorityID:
			producer = proofProducer.NewGuardianProofProducer(encoding.TierGuardianMinorityID, p.cfg.EnableLivenessBondProof)
		case encoding.TierGuardianMajorityID:
			producer = proofProducer.NewGuardianProofProducer(encoding.TierGuardianMajorityID, p.cfg.EnableLivenessBondProof)
		default:
			return fmt.Errorf("unsupported tier: %d", tier.ID)
		}

		if submitter, err = proofSubmitter.NewProofSubmitter(
			p.rpc,
			producer,
			p.proofGenerationCh,
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
		); err != nil {
			return err
		}

		p.proofSubmitters = append(p.proofSubmitters, submitter)
	}

	return nil
}

// initL1Current initializes prover's L1Current cursor.
func (p *Prover) initL1Current(startingBlockID *big.Int) error {
	if err := p.rpc.WaitTillL2ExecutionEngineSynced(p.ctx); err != nil {
		return err
	}

	stateVars, err := p.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: p.ctx})
	if err != nil {
		return err
	}
	p.genesisHeightL1 = stateVars.A.GenesisHeight

	if startingBlockID == nil {
		if stateVars.B.LastVerifiedBlockId == 0 {
			genesisL1Header, err := p.rpc.L1.HeaderByNumber(p.ctx, new(big.Int).SetUint64(stateVars.A.GenesisHeight))
			if err != nil {
				return err
			}

			p.sharedState.SetL1Current(genesisL1Header)
			return nil
		}

		startingBlockID = new(big.Int).SetUint64(stateVars.B.LastVerifiedBlockId)
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
	// ------- BlockProposed -------
	opts := &handler.NewBlockProposedEventHandlerOps{
		SharedState:           p.sharedState,
		ProverAddress:         p.ProverAddress(),
		ProverSetAddress:      p.cfg.ProverSetAddress,
		GenesisHeightL1:       p.genesisHeightL1,
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
		p.blockProposedHandler = handler.NewBlockProposedEventGuardianHandler(
			&handler.NewBlockProposedGuardianEventHandlerOps{
				NewBlockProposedEventHandlerOps: opts,
				GuardianProverHeartbeater:       p.guardianProverHeartbeater,
			},
		)
	} else {
		p.blockProposedHandler = handler.NewBlockProposedEventHandler(opts)
	}
	// ------- TransitionProved -------
	p.transitionProvedHandler = handler.NewTransitionProvedEventHandler(
		p.rpc,
		p.proofContestCh,
		p.proofSubmissionCh,
		p.cfg.ContesterMode,
		p.IsGuardianProver(),
	)
	// ------- TransitionContested -------
	p.transitionContestedHandler = handler.NewTransitionContestedEventHandler(
		p.rpc,
		p.proofSubmissionCh,
		p.cfg.ContesterMode,
	)
	// ------- AssignmentExpired -------
	p.assignmentExpiredHandler = handler.NewAssignmentExpiredEventHandler(
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
		return err
	}
	p.blockVerifiedHandler = handler.NewBlockVerifiedEventHandler(guardianProverAddress)

	return nil
}
