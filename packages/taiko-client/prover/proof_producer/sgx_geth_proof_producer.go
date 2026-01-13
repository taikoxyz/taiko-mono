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
		BatchProof: common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
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
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()
	var (
		output     *RaikoRequestProofBodyResponseV2
		err        error
		batches    = make([]*RaikoBatches, 0, len(opts))
		proposals  = make([]*RaikoProposals, 0, len(opts))
		start, end *big.Int
	)

	if metas[0].IsShasta() {
		for i, meta := range metas {
			proposals = append(proposals, &RaikoProposals{
				ProposalId:             meta.Shasta().GetEventData().Id,
				L1InclusionBlockNumber: meta.GetRawBlockHeight(),
				L2BlockNumbers:         opts[i].ShastaOptions().L2BlockNums,
				Checkpoint: &RaikoCheckpoint{
					BlockNum:  opts[i].ShastaOptions().Checkpoint.BlockNumber,
					BlockHash: common.BytesToHash(opts[i].ShastaOptions().Checkpoint.BlockHash[:]).Hex()[2:],
					StateRoot: common.BytesToHash(opts[i].ShastaOptions().Checkpoint.StateRoot[:]).Hex()[2:],
				},
				LastAnchorBlockNumber: opts[i].ShastaOptions().LastAnchorBlockNumber,
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
	} else {
		for _, meta := range metas {
			batches = append(batches, &RaikoBatches{
				BatchID:                meta.Pacaya().GetBatchID(),
				L1InclusionBlockNumber: meta.GetRawBlockHeight(),
			})
		}
		output, err = requestHTTPProof[RaikoRequestProofBodyV3Pacaya, RaikoRequestProofBodyResponseV2](
			ctx,
			s.RaikoHostEndpoint+"/v3/proof/batch",
			s.ApiKey,
			RaikoRequestProofBodyV3Pacaya{
				Type:      proofType,
				Batches:   batches,
				Prover:    opts[0].GetProverAddress().Hex()[2:],
				Aggregate: isAggregation,
			},
		)
		start, end = batches[0].BatchID, batches[len(batches)-1].BatchID
	}
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
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
