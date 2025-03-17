package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
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

// ProofProducerPacaya generates a proof for the given block.
type ProofProducerPacaya struct {
	Verifiers           map[ProofType]common.Address
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
	PivotProducer       *PivotProofProducer
	ProofType           ProofType
	IsOp                bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (z *ProofProducerPacaya) RequestProof(
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
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	var (
		proof     []byte
		proofType ProofType
		batches   = []*RaikoBatches{{BatchID: batchID, L1InclusionBlockNumber: meta.GetRawBlockHeight()}}
		g         = new(errgroup.Group)
	)

	g.Go(func() error {
		// NOTE: right now we don't use the pivot proof for Pacaya, since its still not ready.
		_, err := z.PivotProducer.RequestProof(ctx, opts, batchID, meta, requestAt)
		return err
	})
	g.Go(func() error {
		if z.IsOp {
			proofType = z.ProofType
			if resp, err := z.DummyProofProducer.RequestProof(opts, batchID, meta, z.Tier(), requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}
		} else {
			if resp, err := z.requestBatchProof(
				ctx,
				batches,
				opts.GetProverAddress(),
				false,
				z.ProofType,
				requestAt,
			); err != nil {
				return err
			} else {
				proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
				proofType = resp.ProofType
			}
		}
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &ProofResponse{
		BlockID:   batchID,
		Meta:      meta,
		Proof:     proof,
		Opts:      opts,
		Tier:      z.Tier(),
		ProofType: proofType,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (z *ProofProducerPacaya) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	proofType := items[0].ProofType
	verifier, exist := z.Verifiers[proofType]
	if !exist {
		return nil, fmt.Errorf("unknown proof type from raiko %s", proofType)
	}
	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"proofType", proofType,
		"batchSize", len(items),
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)
	var (
		g                = new(errgroup.Group)
		pivotBatchProofs *BatchProofs
		batchProofs      []byte
		err              error
		batches          = make([]*RaikoBatches, 0, len(items))
		batchIDs         = make([]*big.Int, 0, len(items))
	)
	for _, item := range items {
		batches = append(batches, &RaikoBatches{
			BatchID:                item.Meta.Pacaya().GetBatchID(),
			L1InclusionBlockNumber: item.Meta.GetRawBlockHeight(),
		})
		batchIDs = append(batchIDs, item.Meta.Pacaya().GetBatchID())
	}
	g.Go(func() error {
		if pivotBatchProofs, err = z.PivotProducer.Aggregate(ctx, items, requestAt); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if z.IsOp {
			proofType = z.ProofType
			resp, _ := z.DummyProofProducer.RequestBatchProofs(items, z.Tier(), z.ProofType)
			batchProofs = resp.BatchProof
		} else {
			if resp, err := z.requestBatchProof(
				ctx,
				batches,
				items[0].Opts.GetProverAddress(),
				true,
				proofType,
				requestAt,
			); err != nil {
				return err
			} else {
				batchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
			}
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:     items,
		BatchProof:         batchProofs,
		Tier:               z.Tier(),
		BlockIDs:           batchIDs,
		ProofType:          proofType,
		Verifier:           verifier,
		PivotBatchProof:    pivotBatchProofs.BatchProof,
		PivotProofVerifier: pivotBatchProofs.Verifier,
		IsPacaya:           true,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (z *ProofProducerPacaya) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return fmt.Errorf("RequestCancel is not implemented for Pacaya proof producer")
}

// Tier implements the ProofProducer interface.
func (z *ProofProducerPacaya) Tier() uint16 {
	return encoding.TierDeprecated
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (z *ProofProducerPacaya) requestBatchProof(
	ctx context.Context,
	batches []*RaikoBatches,
	proverAddress common.Address,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, z.RaikoRequestTimeout)
	defer cancel()

	output, err := requestHttpProof[RaikoRequestProofBodyV3Pacaya, RaikoRequestProofBodyResponseV2](
		ctx,
		z.RaikoHostEndpoint+"/v3/proof/batch",
		z.JWT,
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

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		return nil, fmt.Errorf("failed to get proof, err: %s, msg: %s, type: %s, batches: %v",
			output.Error,
			output.ErrorMessage,
			output.ProofType,
			batches,
		)
	}

	if output.Data == nil {
		return nil, fmt.Errorf("unexpected structure error, proofType: %s", proofType)
	}
	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, ErrProofInProgress
	}
	if output.Data.Status == StatusRegistered {
		return nil, ErrRetry
	}

	if output.Data.Proof == nil ||
		len(output.Data.Proof.Proof) == 0 {
		return nil, errEmptyProof
	}

	log.Info(
		"Batch proof generated",
		"isAggregation", isAggregation,
		"proofType", proofType,
		"start", batches[0].BatchID,
		"end", batches[len(batches)-1].BatchID,
		"time", time.Since(requestAt),
	)

	if isAggregation {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch proofType {
		case ProofTypePivot:
			metrics.ProverPivotProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSGXAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofAggregationGeneratedCounter.Add(1)
		default:
			return nil, fmt.Errorf("unknown proof type: %s", proofType)
		}
	} else {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch output.ProofType {
		case ProofTypePivot:
			metrics.ProverPivotAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofAggregationGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSgxProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofGeneratedCounter.Add(1)
		default:
			return nil, fmt.Errorf("unknown proof type: %s", output.ProofType)
		}
	}
	return output, nil
}
