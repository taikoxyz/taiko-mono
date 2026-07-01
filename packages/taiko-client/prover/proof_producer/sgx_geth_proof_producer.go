package producer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// SgxGethProofProducer generates a sgx geth proof for the given block.
type SgxGethProofProducer struct {
	Verifier            common.Address
	VerifierID          uint8
	RaikoHostEndpoint   string // a prover RPC endpoint
	ApiKey              string // ApiKey provided by Raiko
	Dummy               bool
	RaikoRequestTimeout time.Duration
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *SgxGethProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request proof from raiko-host service",
		"type", ProofTypeSgxGeth,
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
		ProofTypeSgxGeth,
		requestAt,
		opts.IsGethProofGenerated(),
	)
	if err != nil {
		return nil, err
	}

	return &ProofResponse{
		BatchID: batchID,
		Meta:    meta,
		Proof:   common.Hex2Bytes(resp.Data.Proof[2:]),
		Opts:    opts,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *SgxGethProofProducer) Aggregate(
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
		"proofType", ProofTypeSgxGeth,
		"firstID", items[0].BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		resp, _ := s.DummyProofProducer.RequestBatchProofs(items, ProofTypeSgxGeth)
		return &BatchProofs{BatchProof: resp.BatchProof, Verifier: s.Verifier, VerifierID: s.VerifierID}, nil
	}
	var (
		opts  = make([]ProofRequestOptions, 0, len(items))
		metas = make([]metadata.TaikoProposalMetaData, 0, len(items))
		err   error
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
		ProofTypeSgxGeth,
		requestAt,
		items[0].Opts.IsGethProofAggregationGenerated(),
	)
	if err != nil {
		return nil, err
	}

	return &BatchProofs{
		BatchProof: common.Hex2Bytes(resp.Data.Proof[2:]),
		Verifier:   s.Verifier,
		VerifierID: s.VerifierID,
	}, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *SgxGethProofProducer) requestBatchProof(
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
	output, start, end, err := requestRaikoProofV4(
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
