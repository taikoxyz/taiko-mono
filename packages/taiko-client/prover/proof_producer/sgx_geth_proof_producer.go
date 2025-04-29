package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// SgxGethProofProducer generates a sgx geth proof for the given block.
type SgxGethProofProducer struct {
	Verifier            common.Address
	RaikoHostEndpoint   string // a prover RPC endpoint
	JWT                 string // JWT provided by Raiko
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
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, batchID, meta, s.Tier(), requestAt)
	}

	resp, err := s.requestBatchProof(
		ctx,
		[]*RaikoBatches{{BatchID: batchID, L1InclusionBlockNumber: meta.GetRawBlockHeight()}},
		opts.GetProverAddress(),
		false,
		ProofTypeSgxGeth,
		requestAt,
		opts.PacayaOptions().IsGethProofGenerated,
	)
	if err != nil {
		return nil, err
	}

	return &ProofResponse{
		BlockID: batchID,
		Meta:    meta,
		Proof:   common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
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
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		resp, _ := s.DummyProofProducer.RequestBatchProofs(items, s.Tier(), ProofTypeSgxGeth)
		return &BatchProofs{BatchProof: resp.BatchProof, Verifier: s.Verifier}, nil
	}

	batches := make([]*RaikoBatches, 0, len(items))
	for _, item := range items {
		batches = append(batches, &RaikoBatches{
			BatchID:                item.Meta.Pacaya().GetBatchID(),
			L1InclusionBlockNumber: item.Meta.GetRawBlockHeight(),
		})
	}

	resp, err := s.requestBatchProof(
		ctx,
		batches,
		items[0].Opts.GetProverAddress(),
		true,
		ProofTypeSgxGeth,
		requestAt,
		items[0].Opts.PacayaOptions().IsGethProofAggregationGenerated,
	)
	if err != nil {
		return nil, err
	}

	return &BatchProofs{BatchProof: common.Hex2Bytes(resp.Data.Proof.Proof[2:]), Verifier: s.Verifier}, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *SgxGethProofProducer) requestBatchProof(
	ctx context.Context,
	batches []*RaikoBatches,
	proverAddress common.Address,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	output, err := requestHTTPProof[RaikoRequestProofBodyV3Pacaya, RaikoRequestProofBodyResponseV2](
		ctx,
		s.RaikoHostEndpoint+"/v3/proof/batch",
		s.JWT,
		RaikoRequestProofBodyV3Pacaya{
			Type:      proofType,
			Batches:   batches,
			Prover:    proverAddress.Hex()[2:],
			Aggregate: isAggregation,
		},
	)
	if err != nil {
		return nil, err
	}

	if err := output.Validate(); err != nil {
		return nil, fmt.Errorf("invalid Raiko response(start: %d, end: %d): %w",
			batches[0].BatchID,
			batches[len(batches)-1].BatchID,
			err,
		)
	}

	log.Info(
		"Batch proof generated",
		"start", batches[0].BatchID,
		"end", batches[len(batches)-1].BatchID,
		"isAggregation", isAggregation,
		"proofType", proofType,
		"time", time.Since(requestAt),
	)

	if !alreadyGenerated {
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}

// Tier implements the ProofProducer interface.
func (s *SgxGethProofProducer) Tier() uint16 {
	return encoding.TierDeprecated
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (s *SgxGethProofProducer) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return fmt.Errorf("RequestCancel is not implemented for Pacaya proof producer")
}
