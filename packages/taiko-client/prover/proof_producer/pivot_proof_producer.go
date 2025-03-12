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

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// PivotProofProducer generates a pivot proof for the given block.
// TODO: Can be refactored like ProofProducerPacaya
type PivotProofProducer struct {
	Verifier            common.Address
	RaikoHostEndpoint   string // a prover RPC endpoint
	JWT                 string // JWT provided by Raiko
	Dummy               bool
	RaikoRequestTimeout time.Duration
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *PivotProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request proof from raiko-host service",
		"type", ProofTypePivot,
		"batchID", batchID,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, batchID, meta, s.Tier(), requestAt)
	}

	batches := []*RaikoBatches{
		{
			BatchID:                batchID,
			L1InclusionBlockNumber: meta.GetRawBlockHeight(),
		},
	}
	if resp, err := s.requestBatchProof(
		ctx,
		batches,
		opts.GetProverAddress(),
		false,
		ProofTypePivot,
		requestAt,
	); err != nil {
		return nil, err
	} else {
		return &ProofResponse{
			BlockID: batchID,
			Meta:    meta,
			Proof:   common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
			Opts:    opts,
		}, nil
	}
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *PivotProofProducer) Aggregate(
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
		"proofType", ProofTypePivot,
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		resp, _ := s.DummyProofProducer.RequestBatchProofs(items, s.Tier(), ProofTypePivot)
		return &BatchProofs{
			BatchProof: resp.BatchProof,
			Verifier:   s.Verifier,
		}, nil
	}

	batches := make([]*RaikoBatches, 0, len(items))
	for _, item := range items {
		batches = append(batches, &RaikoBatches{
			BatchID:                item.Meta.Pacaya().GetBatchID(),
			L1InclusionBlockNumber: item.Meta.GetRawBlockHeight(),
		})
	}
	if resp, err := s.requestBatchProof(
		ctx,
		batches,
		items[0].Opts.GetProverAddress(),
		true,
		ProofTypePivot,
		requestAt,
	); err != nil {
		return nil, err
	} else {
		return &BatchProofs{
			BatchProof: common.Hex2Bytes(resp.Data.Proof.Proof[2:]),
			Verifier:   s.Verifier,
		}, nil
	}
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *PivotProofProducer) requestBatchProof(
	ctx context.Context,
	batches []*RaikoBatches,
	proverAddress common.Address,
	isAggregation bool,
	proofType string,
	requestAt time.Time,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
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
		"batches", batches,
		"proofType", proofType,
		"isAggregation", isAggregation,
		"input", string(jsonValue),
	)

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		s.RaikoHostEndpoint+"/v3/proof/batch",
		bytes.NewBuffer(jsonValue),
	)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(s.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(s.JWT)))
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
		"batches", batches,
		"isAggregation", isAggregation,
		"proofType", proofType,
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

// Tier implements the ProofProducer interface.
func (s *PivotProofProducer) Tier() uint16 {
	return encoding.TierDeprecated
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (s *PivotProofProducer) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return fmt.Errorf("RequestCancel is not implemented for Pacaya proof producer")
}
