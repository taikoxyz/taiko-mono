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

// TdxZkComposeProofProducer generates a TDX + ZK compose proof for the given block.
// Sub-proofs are submitted as [TDX_RETH, ZK_RETH] in ascending VerifierType order,
// matching the TdxAndZkVerifier contract.
type TdxZkComposeProofProducer struct {
	// VerifierIDs maps ZK proof types to their on-chain VerifierType enum values.
	VerifierIDs           map[ProofType]uint8
	RaikoZKVMHostEndpoint string
	RaikoRequestTimeout   time.Duration
	ApiKey                string
	TdxProducer           *TdxProofProducer
	ProofType             ProofType // ZK proof type: ProofTypeZKAny, ProofTypeZKSP1, or ProofTypeZKR0
	Dummy                 bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *TdxZkComposeProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	proposalID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request TDX+ZK compose proof from raiko-host services",
		"proposalID", proposalID,
		"zkProofType", s.ProofType,
		"time", time.Since(requestAt),
		"dummy", s.Dummy,
	)

	var (
		proof        []byte
		proofType    ProofType
		g            = new(errgroup.Group)
		zkProofError error
	)

	g.Go(func() error {
		if s.Dummy {
			// Aggregate() rejects zk_any (it has no VerifierID), so resolve to a concrete
			// ZK type for the dummy flow used by local/dev runs.
			proofType = s.resolveDummyZKProofType()
			if resp, err := s.DummyProofProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}
		} else {
			if resp, err := s.requestZKBatchProof(
				ctx,
				[]ProofRequestOptions{opts},
				[]metadata.TaikoProposalMetaData{meta},
				false,
				s.ProofType,
				requestAt,
				opts.IsRethProofGenerated(),
			); err != nil {
				zkProofError = err
				return err
			} else {
				proofType = resp.ProofType
				opts.ProposalOptions().RethProofGenerated = true
				if ProofTypeZKSP1 != proofType {
					proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
				}
			}
		}
		return nil
	})

	g.Go(func() error {
		if _, err := s.TdxProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
			return err
		}
		opts.ProposalOptions().GethProofGenerated = true
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get TDX+ZK proofs: %w and %w", err, zkProofError)
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
func (s *TdxZkComposeProofProducer) Aggregate(
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
		exist      bool
	)
	if verifierID, exist = s.VerifierIDs[proofType]; !exist {
		return nil, fmt.Errorf("unknown ZK proof type from raiko: %s", proofType)
	}

	log.Info(
		"Aggregate TDX+ZK compose batch proofs from raiko-host services",
		"zkProofType", proofType,
		"batchSize", len(items),
		"firstID", items[0].BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)

	var (
		tdxBatchProofs *BatchProofs
		zkBatchProof   []byte
		batchIDs       = make([]*big.Int, 0, len(items))
		opts           = make([]ProofRequestOptions, 0, len(items))
		metas          = make([]metadata.TaikoProposalMetaData, 0, len(items))
		g              = new(errgroup.Group)
		err            error
	)

	for _, item := range items {
		opts = append(opts, item.Opts)
		metas = append(metas, item.Meta)
		batchIDs = append(batchIDs, item.Meta.GetProposalID())
	}

	g.Go(func() error {
		if tdxBatchProofs, err = s.TdxProducer.Aggregate(ctx, items, requestAt); err != nil {
			return err
		}
		items[0].Opts.ProposalOptions().GethProofAggregationGenerated = true
		return nil
	})

	g.Go(func() error {
		if s.Dummy {
			proofType = s.resolveDummyZKProofType()
			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, proofType)
			zkBatchProof = resp.BatchProof
		} else {
			if resp, err := s.requestZKBatchProof(
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
				items[0].Opts.ProposalOptions().RethProofAggregationGenerated = true
				zkBatchProof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
			}
		}
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to aggregate TDX+ZK proofs: %w", err)
	}

	// VerifierType enum (ComposeVerifier.sol): RISC0_RETH = 5, SP1_RETH = 6, TDX_RETH = 7.
	// The compose verifier requires sub-proofs in strictly ascending VerifierID order, so
	// the ZK proof is encoded first (BatchProof / VerifierID) and the TDX proof second
	// (TdxBatchProof / TdxVerifierID). The submitter sorts by VerifierID on encoding.
	return &BatchProofs{
		ProofResponses:   items,
		BatchProof:       zkBatchProof,
		BatchIDs:         batchIDs,
		ProofType:        proofType,
		VerifierID:       verifierID,
		TdxBatchProof:    tdxBatchProofs.BatchProof,
		TdxProofVerifier: tdxBatchProofs.Verifier,
		TdxVerifierID:    tdxBatchProofs.VerifierID,
	}, nil
}

// resolveDummyZKProofType returns a concrete ZK proof type for the dummy flow.
// s.ProofType may be ProofTypeZKAny, which Aggregate() rejects because it has no
// associated VerifierID. ProofTypeZKR0 is used as the default concrete type.
func (s *TdxZkComposeProofProducer) resolveDummyZKProofType() ProofType {
	if s.ProofType == ProofTypeZKAny {
		return ProofTypeZKR0
	}
	return s.ProofType
}

func (s *TdxZkComposeProofProducer) requestZKBatchProof(
	ctx context.Context,
	opts []ProofRequestOptions,
	metas []metadata.TaikoProposalMetaData,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	if len(opts) == 0 || len(opts) != len(metas) {
		return nil, ErrInvalidLength
	}

	var (
		output    *RaikoRequestProofBodyResponseV2
		err       error
		proposals = make([]*RaikoProposals, 0, len(opts))
		start     *big.Int
		end       *big.Int
	)

	for i, meta := range metas {
		proposals = append(proposals, &RaikoProposals{
			ProposalId:             meta.Shasta().GetEventData().Id,
			L1InclusionBlockNumber: meta.GetRawBlockHeight(),
			L2BlockNumbers:         opts[i].ProposalOptions().L2BlockNums,
			Checkpoint: &RaikoCheckpoint{
				BlockNum:  opts[i].ProposalOptions().Checkpoint.BlockNumber,
				BlockHash: common.BytesToHash(opts[i].ProposalOptions().Checkpoint.BlockHash[:]).Hex()[2:],
				StateRoot: common.BytesToHash(opts[i].ProposalOptions().Checkpoint.StateRoot[:]).Hex()[2:],
			},
			LastAnchorBlockNumber: opts[i].ProposalOptions().LastAnchorBlockNumber,
		})
	}

	output, err = requestHTTPProof[RaikoRequestProofBodyV3Shasta, RaikoRequestProofBodyResponseV2](
		ctx,
		s.RaikoZKVMHostEndpoint+"/v3/proof/batch/shasta",
		s.ApiKey,
		RaikoRequestProofBodyV3Shasta{
			Type:      proofType,
			Proposals: proposals,
			Prover:    opts[0].GetProverAddress().Hex()[2:],
			Aggregate: isAggregation,
		},
	)
	start, end = proposals[0].ProposalId, proposals[len(proposals)-1].ProposalId
	if err != nil {
		return nil, err
	}

	if err := output.Validate(); err != nil {
		log.Debug(
			"ZK proof output validation result",
			"start", start,
			"end", end,
			"proofType", output.ProofType,
			"err", err,
		)
		return nil, fmt.Errorf("invalid Raiko ZK response(start: %d, end: %d): %w", start, end, err)
	}

	if !alreadyGenerated {
		proofType = output.ProofType
		log.Info(
			"TDX+ZK batch proof generated",
			"isAggregation", isAggregation,
			"proofType", proofType,
			"start", start,
			"end", end,
			"time", time.Since(requestAt),
		)
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
