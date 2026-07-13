package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type RaikoCheckpoint struct {
	BlockNum  *big.Int `json:"block_number"`
	BlockHash string   `json:"block_hash"`
	StateRoot string   `json:"state_root"`
}

// RaikoRequestProofBodyV4 represents the JSON body for requesting a v4 proposal-side proof task.
type RaikoRequestProofBodyV4 struct {
	ProofType ProofType          `json:"proof_type"`
	Aggregate bool               `json:"aggregate"`
	Proposals []*RaikoProposalV4 `json:"proposals"`
	Prover    string             `json:"prover,omitempty"`
}

// RaikoProposalV4 represents one proposal carried by a v4 proof request.
type RaikoProposalV4 struct {
	ProposalID             *big.Int         `json:"proposal_id"`
	Checkpoint             *RaikoCheckpoint `json:"checkpoint,omitempty"`
	L1InclusionBlockNumber *big.Int         `json:"l1_inclusion_block_number"`
	L2BlockNumberStart     *big.Int         `json:"l2_block_number_start"`
	L2BlockNumberEnd       *big.Int         `json:"l2_block_number_end"`
	LastAnchorBlockNumber  *big.Int         `json:"last_anchor_block_number"`
}

// ComposeProofProducer generates a compose proof for the given block.
type ComposeProofProducer struct {
	// VerifierIDs are used for proof requests.
	VerifierIDs         map[ProofType]uint8
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	ApiKey              string // ApiKey provided by Raiko
	SgxGethProducer     *SgxGethProofProducer
	ProofType           ProofType
	// ZkOnly pairs the primary SP1 proof with a RISC0 companion proof instead of an
	// SGX_GETH proof, producing the [RISC0_RETH, SP1_RETH] combination that
	// ZkRequiredVerifier accepts without any TEE leg.
	ZkOnly bool
	Dummy  bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ComposeProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	proposalID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	requestProofType := s.ProofType
	if s.ZkOnly {
		// In ZK-only mode SP1 is always the primary proof lane, and the RISC0 proof is
		// requested as the companion leg alongside it.
		requestProofType = ProofTypeZKSP1
	} else if opts.ProposalOptions().ProofType != "" {
		requestProofType = opts.ProposalOptions().ProofType
	}

	log.Info(
		"Request proof from raiko-host service",
		"proposalID", proposalID,
		"proofType", requestProofType,
		"time", time.Since(requestAt),
		"dummy", s.Dummy,
	)

	var (
		proof          []byte
		proofType      ProofType
		g              = new(errgroup.Group)
		rethProofError error
	)

	g.Go(func() error {
		if s.Dummy {
			proofType = requestProofType
			if resp, err := s.DummyProofProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				[]ProofRequestOptions{opts},
				[]metadata.TaikoProposalMetaData{meta},
				false,
				requestProofType,
				requestAt,
				opts.IsRethProofGenerated(),
			); err != nil {
				rethProofError = err
				return err
			} else {
				proofType = resp.ProofType
				// Note: we mark `RethProofGenerated` with true to record if it is first time generated.
				opts.ProposalOptions().RethProofGenerated = true
				// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
				if ProofTypeZKSP1 != proofType {
					proof = common.Hex2Bytes(resp.Data.Proof[2:])
				}
			}
		}
		return nil
	})

	g.Go(func() error {
		if s.ZkOnly {
			return s.requestRisc0CompanionProof(ctx, opts, meta, requestAt)
		}
		if _, err := s.SgxGethProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
			return err
		} else {
			// Note: we mark `GethProofGenerated` with true to record if it is the first time generated.
			opts.ProposalOptions().GethProofGenerated = true
			return nil
		}
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w and %w", err, rethProofError)
	}

	return &ProofResponse{
		BatchID:   proposalID,
		Meta:      meta,
		Proof:     proof,
		Opts:      opts,
		ProofType: proofType,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *ComposeProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	proofType := items[0].ProofType
	var (
		verifierID uint8
		verifier   common.Address
		exist      bool
	)
	if verifierID, exist = s.VerifierIDs[proofType]; !exist {
		return nil, fmt.Errorf("unknown proof type from raiko %s", proofType)
	}

	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"proofType", proofType,
		"batchSize", len(items),
		"firstID", items[0].BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)
	var (
		companionBatchProof []byte
		companionVerifierID uint8
		batchProofs         []byte
		batchIDs            = make([]*big.Int, 0, len(items))
		opts                = make([]ProofRequestOptions, 0, len(items))
		metas               = make([]metadata.TaikoProposalMetaData, 0, len(items))
		g                   = new(errgroup.Group)
	)
	if s.ZkOnly {
		if companionVerifierID, exist = s.VerifierIDs[ProofTypeZKR0]; !exist {
			return nil, fmt.Errorf("no verifier ID for the %s companion proof", ProofTypeZKR0)
		}
	}
	for _, item := range items {
		opts = append(opts, item.Opts)
		metas = append(metas, item.Meta)
		batchIDs = append(batchIDs, item.Meta.GetProposalID())
	}
	g.Go(func() error {
		if s.ZkOnly {
			proof, err := s.aggregateRisc0CompanionProofs(ctx, opts, metas, items, requestAt)
			if err != nil {
				return err
			}
			companionBatchProof = proof
			return nil
		}
		sgxGethBatchProofs, err := s.SgxGethProducer.Aggregate(ctx, items, requestAt)
		if err != nil {
			return err
		}
		// Note: we mark `GethProofAggregationGenerated` in the first item with true.
		items[0].Opts.ProposalOptions().GethProofAggregationGenerated = true
		companionBatchProof = sgxGethBatchProofs.BatchProof
		companionVerifierID = sgxGethBatchProofs.VerifierID
		return nil
	})
	g.Go(func() error {
		if s.Dummy {
			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, proofType)
			batchProofs = resp.BatchProof
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				opts,
				metas,
				true,
				proofType,
				requestAt,
				items[0].Opts.IsRethProofAggregationGenerated(),
			); err != nil {
				return err
			} else {
				// Note: we mark `RethProofAggregationGenerated` in the first item with true.
				items[0].Opts.ProposalOptions().RethProofAggregationGenerated = true
				batchProofs = common.Hex2Bytes(resp.Data.Proof[2:])
			}
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:      items,
		BatchProof:          batchProofs,
		BatchIDs:            batchIDs,
		ProofType:           proofType,
		Verifier:            verifier,
		VerifierID:          verifierID,
		CompanionBatchProof: companionBatchProof,
		CompanionVerifierID: companionVerifierID,
	}, nil
}

// requestRisc0CompanionProof requests the RISC0 companion proof for the given proposal in
// ZK-only mode, taking the place of the SGX_GETH leg. Like that leg, only the generation
// status matters here: the proof bytes submitted on-chain come from the aggregation.
func (s *ComposeProofProducer) requestRisc0CompanionProof(
	ctx context.Context,
	opts ProofRequestOptions,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) error {
	if s.Dummy {
		return nil
	}
	if _, err := s.requestBatchProof(
		ctx,
		[]ProofRequestOptions{opts},
		[]metadata.TaikoProposalMetaData{meta},
		false,
		ProofTypeZKR0,
		requestAt,
		opts.ProposalOptions().Risc0CompanionProofGenerated,
	); err != nil {
		return err
	}
	// Note: we mark `Risc0CompanionProofGenerated` with true to record if it is the first time generated.
	opts.ProposalOptions().Risc0CompanionProofGenerated = true
	return nil
}

// aggregateRisc0CompanionProofs aggregates the RISC0 companion proofs of the given items in
// ZK-only mode, taking the place of the SGX_GETH aggregation leg.
func (s *ComposeProofProducer) aggregateRisc0CompanionProofs(
	ctx context.Context,
	opts []ProofRequestOptions,
	metas []metadata.TaikoProposalMetaData,
	items []*ProofResponse,
	requestAt time.Time,
) ([]byte, error) {
	if s.Dummy {
		resp, _ := s.DummyProofProducer.RequestBatchProofs(items, ProofTypeZKR0)
		return resp.BatchProof, nil
	}
	resp, err := s.requestBatchProof(
		ctx,
		opts,
		metas,
		true,
		ProofTypeZKR0,
		requestAt,
		items[0].Opts.ProposalOptions().Risc0CompanionProofAggregationGenerated,
	)
	if err != nil {
		return nil, err
	}
	// Note: we mark `Risc0CompanionProofAggregationGenerated` in the first item with true.
	items[0].Opts.ProposalOptions().Risc0CompanionProofAggregationGenerated = true
	return common.Hex2Bytes(resp.Data.Proof[2:]), nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *ComposeProofProducer) requestBatchProof(
	ctx context.Context,
	opts []ProofRequestOptions,
	metas []metadata.TaikoProposalMetaData,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponse, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()
	output, start, end, err := requestRaikoProposalProofV4(
		ctx,
		s.RaikoHostEndpoint,
		s.ApiKey,
		opts,
		metas,
		isAggregation,
		proofType,
	)
	if err != nil {
		return nil, err
	}
	return validateRaikoProofResponse(output, start, end, proofType, isAggregation, requestAt, alreadyGenerated)
}

func requestRaikoProposalProofV4(
	ctx context.Context,
	raikoHostEndpoint string,
	apiKey string,
	opts []ProofRequestOptions,
	metas []metadata.TaikoProposalMetaData,
	isAggregation bool,
	proofType ProofType,
) (*RaikoRequestProofBodyResponse, *big.Int, *big.Int, error) {
	if len(opts) == 0 || len(opts) != len(metas) {
		return nil, nil, nil, ErrInvalidLength
	}
	var (
		output    *RaikoRequestProofBodyResponse
		err       error
		start     *big.Int
		end       *big.Int
		proposals = make([]*RaikoProposalV4, 0, len(opts))
	)

	if !isAggregation && len(opts) != 1 {
		return nil, nil, nil, ErrInvalidLength
	}
	for i, meta := range metas {
		l2BlockNums := opts[i].ProposalOptions().L2BlockNums
		if len(l2BlockNums) == 0 {
			return nil, nil, nil, ErrInvalidLength
		}
		proposals = append(proposals, &RaikoProposalV4{
			ProposalID:             meta.GetProposalID(),
			Checkpoint:             raikoCheckpointFromOptions(opts[i].ProposalOptions()),
			L1InclusionBlockNumber: meta.GetRawBlockHeight(),
			L2BlockNumberStart:     l2BlockNums[0],
			L2BlockNumberEnd:       l2BlockNums[len(l2BlockNums)-1],
			LastAnchorBlockNumber:  opts[i].ProposalOptions().LastAnchorBlockNumber,
		})
	}
	start, end = metas[0].GetProposalID(), metas[len(metas)-1].GetProposalID()
	output, err = requestHTTPProof[RaikoRequestProofBodyV4, RaikoRequestProofBodyResponse](
		ctx,
		raikoHostEndpoint+"/v4/proof/proposal",
		apiKey,
		RaikoRequestProofBodyV4{
			ProofType: proofType,
			Aggregate: isAggregation,
			Proposals: proposals,
			Prover:    opts[0].GetProverAddress().Hex(),
		},
	)
	if err != nil {
		return nil, nil, nil, err
	}

	return output, start, end, nil
}

func validateRaikoProofResponse(
	output *RaikoRequestProofBodyResponse,
	start *big.Int,
	end *big.Int,
	proofType ProofType,
	isAggregation bool,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponse, error) {
	if err := output.Validate(); err != nil {
		log.Debug(
			"Proof output validation result",
			"start", start,
			"end", end,
			"proofType", output.ProofType,
			"err", err,
		)
		return nil, fmt.Errorf("invalid Raiko response(start: %d, end: %d): %w",
			start,
			end,
			err,
		)
	}
	if output.ProofType != proofType {
		return nil, fmt.Errorf(
			"unexpected proof type from raiko: requested %s, got %s",
			proofType,
			output.ProofType,
		)
	}

	if !alreadyGenerated {
		log.Info(
			"Batch proof generated",
			"isAggregation", isAggregation,
			"proofType", proofType,
			"start", start,
			"end", end,
			"time", time.Since(requestAt),
		)
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}

func raikoCheckpointFromOptions(opts *ProposalProofRequestOptions) *RaikoCheckpoint {
	if opts.Checkpoint == nil {
		return nil
	}
	return &RaikoCheckpoint{
		BlockNum:  opts.Checkpoint.BlockNumber,
		BlockHash: common.BytesToHash(opts.Checkpoint.BlockHash[:]).Hex()[2:],
		StateRoot: common.BytesToHash(opts.Checkpoint.StateRoot[:]).Hex()[2:],
	}
}
