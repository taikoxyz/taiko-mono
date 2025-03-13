package producer

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	ProofTypePivot = "pivot"
	ProofTypeOp    = "op"
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
	Type      string          `json:"proof_type"`
}

// ProofProducerPacaya generates a proof for the given block.
type ProofProducerPacaya struct {
	Verifiers           map[string]common.Address
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
	PivotProducer       PivotProofProducer
	ProofType           string
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
		return nil, fmt.Errorf("current proposal is not Pacaya proposal")
	}

	log.Info(
		"Request proof from raiko-host service",
		"batchID", batchID,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	var (
		proof     []byte
		proofType string
		batches   = []*RaikoBatches{
			{
				BatchID:                batchID,
				L1InclusionBlockNumber: meta.GetRawBlockHeight(),
			},
		}
	)

	g := new(errgroup.Group)

	g.Go(func() error {
		if _, err := z.PivotProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
			return err
		}
		return nil
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
	proofType string,
	requestAt time.Time,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, z.RaikoRequestTimeout)
	defer cancel()

	reqBody := RaikoRequestProofBodyV3Pacaya{
		Type:      proofType,
		Batches:   batches,
		Prover:    proverAddress.Hex()[2:],
		Aggregate: isAggregation,
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Send batch proof generation request",
		"proofType", proofType,
		"isAggregation", isAggregation,
		"start", batches[0].BatchID,
		"end", batches[len(batches)-1].BatchID,
		"input", string(jsonValue),
	)

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		z.RaikoHostEndpoint+"/v3/proof/batch",
		bytes.NewBuffer(jsonValue),
	)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(z.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(z.JWT)))
	}

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to request batch proof, batches: %v, statusCode: %d", batches, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Batch proof generation output",
		"proofType", proofType,
		"isAggregation", isAggregation,
		"start", batches[0].BatchID,
		"end", batches[len(batches)-1].BatchID,
		"output", string(resBytes),
	)

	var output RaikoRequestProofBodyResponseV2
	if err := json.Unmarshal(resBytes, &output); err != nil {
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
		return nil, fmt.Errorf("unexpected structure error, response: %s", string(resBytes))
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
		switch proofType {
		case ProofTypePivot:
			metrics.ProverPivotProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSGXAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)
		case ZKProofTypeR0:
			metrics.ProverR0AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofAggregationGeneratedCounter.Add(1)
		case ZKProofTypeSP1:
			metrics.ProverSP1AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofAggregationGeneratedCounter.Add(1)
		default:
			return nil, fmt.Errorf("unknown proof type: %s", proofType)
		}
	} else {
		switch output.ProofType {
		case ProofTypePivot:
			metrics.ProverPivotAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofAggregationGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSgxProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofGeneratedCounter.Add(1)
		case ZKProofTypeR0:
			metrics.ProverR0ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofGeneratedCounter.Add(1)
		case ZKProofTypeSP1:
			metrics.ProverSP1ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofGeneratedCounter.Add(1)
		default:
			return nil, fmt.Errorf("unknown proof type: %s", output.ProofType)
		}
	}
	return &output, nil
}
