package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// TdxProofProducer generates a TDX proof for the given block.
type TdxProofProducer struct {
	Verifier            common.Address
	VerifierID          uint8
	RaikoHostEndpoint   string
	ApiKey              string
	Dummy               bool
	RaikoRequestTimeout time.Duration
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *TdxProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request proof from raiko-host service",
		"type", ProofTypeTdx,
		"batchID", batchID,
		"time", time.Since(requestAt),
		"dummy", s.Dummy,
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(ctx, opts, batchID, meta, requestAt)
	}

	resp, err := s.requestBatchProof(
		ctx,
		[]ProofRequestOptions{opts},
		[]metadata.TaikoProposalMetaData{meta},
		false,
		ProofTypeTdx,
		requestAt,
		opts.IsGethProofGenerated(),
	)
	if err != nil {
		return nil, err
	}

	return &ProofResponse{
		BatchID: batchID,
		Meta:    meta,
		Proof:   common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
		Opts:    opts,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *TdxProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}

	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"batchSize", len(items),
		"proofType", ProofTypeTdx,
		"firstID", items[0].BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		resp, _ := s.DummyProofProducer.RequestBatchProofs(items, ProofTypeTdx)
		return &BatchProofs{BatchProof: resp.BatchProof, Verifier: s.Verifier, VerifierID: s.VerifierID}, nil
	}

	var (
		opts  = make([]ProofRequestOptions, 0, len(items))
		metas = make([]metadata.TaikoProposalMetaData, 0, len(items))
	)

	for _, item := range items {
		opts = append(opts, item.Opts)
		metas = append(metas, item.Meta)
	}

	resp, err := s.requestBatchProof(
		ctx,
		opts,
		metas,
		true,
		ProofTypeTdx,
		requestAt,
		items[0].Opts.IsGethProofAggregationGenerated(),
	)
	if err != nil {
		return nil, err
	}

	return &BatchProofs{
		BatchProof: common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
		Verifier:   s.Verifier,
		VerifierID: s.VerifierID,
	}, nil
}

func (s *TdxProofProducer) requestBatchProof(
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
		s.RaikoHostEndpoint+"/v3/proof/batch/shasta",
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
		return nil, fmt.Errorf(
			"invalid Raiko response(start: %d, end: %d): %w",
			start,
			end,
			err,
		)
	}

	if !alreadyGenerated {
		log.Info(
			"Batch proof generated",
			"start", start,
			"end", end,
			"isAggregation", isAggregation,
			"proofType", proofType,
			"time", time.Since(requestAt),
		)
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
