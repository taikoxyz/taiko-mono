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

// RaikoBatches represents the JSON body of RaikoRequestProofBodyV3Pacaya's `Batches` field.
type RaikoBatches struct {
	BatchID                *big.Int `json:"batch_id"`
	L1InclusionBlockNumber *big.Int `json:"l1_inclusion_block_number"`
}

// RaikoRequestProofBodyV3Pacaya represents the JSON body for requesting the proof.
type RaikoRequestProofBodyV3Pacaya struct {
	Batches   []*RaikoBatches `json:"batches"`
	Prover    string          `json:"prover"`
	Aggregate bool            `json:"aggregate"`
	Type      ProofType       `json:"proof_type"`
}

// ComposeProofProducer generates a compose proof for the given block.
type ComposeProofProducer struct {
	Verifiers           map[ProofType]common.Address
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	ApiKey              string // ApiKey provided by Raiko
	SgxGethProducer     *SgxGethProofProducer
	ProofType           ProofType
	Dummy               bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ComposeProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	if !meta.IsPacaya() {
		return nil, fmt.Errorf("current proposal (%d) is not a Pacaya proposal", batchID)
	}

	log.Info(
		"Request proof from raiko-host service",
		"batchID", batchID,
		"proofType", s.ProofType,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	var (
		proof          []byte
		proofType      ProofType
		batches        = []*RaikoBatches{{BatchID: batchID, L1InclusionBlockNumber: meta.GetRawBlockHeight()}}
		g              = new(errgroup.Group)
		rethProofError error
	)

	g.Go(func() error {
		if s.Dummy {
			proofType = s.ProofType
			if resp, err := s.DummyProofProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				batches,
				opts.GetProverAddress(),
				false,
				s.ProofType,
				requestAt,
				opts.PacayaOptions().IsRethProofGenerated,
			); err != nil {
				rethProofError = err
				return err
			} else {
				proofType = resp.ProofType
				// Note: we mark the `IsRethProofGenerated` with true to record if it is first time generated
				opts.PacayaOptions().IsRethProofGenerated = true
				// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
				if ProofTypeZKSP1 != proofType {
					proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
				}
			}
		}
		return nil
	})

	g.Go(func() error {
		if _, err := s.SgxGethProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
			return err
		} else {
			// Note: we mark the `IsGethProofGenerated` with true to record if it is the first time generated
			opts.PacayaOptions().IsGethProofGenerated = true
			return nil
		}
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w and %w", err, rethProofError)
	}

	return &ProofResponse{
		BatchID:   batchID,
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
	verifier, exist := s.Verifiers[proofType]
	if !exist {
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
		sgxGethBatchProofs *BatchProofs
		batchProofs        []byte
		batches            = make([]*RaikoBatches, 0, len(items))
		batchIDs           = make([]*big.Int, 0, len(items))
		g                  = new(errgroup.Group)
		err                error
	)
	for _, item := range items {
		batches = append(batches, &RaikoBatches{
			BatchID:                item.Meta.Pacaya().GetBatchID(),
			L1InclusionBlockNumber: item.Meta.GetRawBlockHeight(),
		})
		batchIDs = append(batchIDs, item.Meta.Pacaya().GetBatchID())
	}
	g.Go(func() error {
		if sgxGethBatchProofs, err = s.SgxGethProducer.Aggregate(ctx, items, requestAt); err != nil {
			return err
		} else {
			// Note: we mark the `IsGethProofAggregationGenerated` in the first item with true
			// to record if it is first time generated
			items[0].Opts.PacayaOptions().IsGethProofAggregationGenerated = true
			return nil
		}
	})
	g.Go(func() error {
		if s.Dummy {
			proofType = s.ProofType
			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, s.ProofType)
			batchProofs = resp.BatchProof
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				batches,
				items[0].Opts.GetProverAddress(),
				true,
				proofType,
				requestAt,
				items[0].Opts.PacayaOptions().IsRethProofAggregationGenerated,
			); err != nil {
				return err
			} else {
				// Note: we mark the `IsRethProofAggregationGenerated` in the first item with true
				// to record if it is first time generated
				items[0].Opts.PacayaOptions().IsRethProofAggregationGenerated = true
				batchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
			}
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:       items,
		BatchProof:           batchProofs,
		BatchIDs:             batchIDs,
		ProofType:            proofType,
		Verifier:             verifier,
		SgxGethBatchProof:    sgxGethBatchProofs.BatchProof,
		SgxGethProofVerifier: sgxGethBatchProofs.Verifier,
	}, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *ComposeProofProducer) requestBatchProof(
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
		s.ApiKey,
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
		log.Debug(
			"Proof output validation result",
			"start", batches[0].BatchID,
			"end", batches[len(batches)-1].BatchID,
			"proofType", output.ProofType,
			"err", err,
		)
		return nil, fmt.Errorf("invalid Raiko response(start: %d, end: %d): %w",
			batches[0].BatchID,
			batches[len(batches)-1].BatchID,
			err,
		)
	}

	if !alreadyGenerated {
		proofType = output.ProofType
		log.Info(
			"Batch proof generated",
			"isAggregation", isAggregation,
			"proofType", proofType,
			"start", batches[0].BatchID,
			"end", batches[len(batches)-1].BatchID,
			"time", time.Since(requestAt),
		)
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
