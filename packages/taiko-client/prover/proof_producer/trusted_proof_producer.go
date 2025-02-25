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

const (
	ProofTypeTrusted = "trusted"
)

// TrustedProofProducer generates a trusted proof for the given block.
type TrustedProofProducer struct {
	Verifier            common.Address
	RaikoHostEndpoint   string // a proverd RPC endpoint
	ProofType           string // Proof type
	JWT                 string // JWT provided by Raiko
	Dummy               bool
	RaikoRequestTimeout time.Duration
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *TrustedProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request proof from raiko-host service",
		"type", s.ProofType,
		"batchID", batchID,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, batchID, meta, s.Tier(), requestAt)
	}

	proof, err := s.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
	}

	if s.ProofType == ProofTypeTrusted {
		metrics.ProverTrustedProofGeneratedCounter.Add(1)
	} else if s.ProofType == ProofTypeSgx {
		metrics.ProverSgxProofGeneratedCounter.Add(1)
	}

	return &ProofResponse{
		BlockID: batchID,
		Meta:    meta,
		Proof:   proof,
		Opts:    opts,
		Tier:    s.Tier(),
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *TrustedProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"batchSize", len(items),
		"proofType", s.ProofType,
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}

	batchIDs := make([]*big.Int, len(items))
	for i, item := range items {
		batchIDs[i] = item.Meta.Pacaya().GetBatchID()
	}
	batchProof, err := s.requestBatchProof(
		ctx,
		batchIDs,
		items[0].Opts.GetProverAddress(),
		items[0].Opts.GetGraffiti(),
		requestAt,
	)
	if err != nil {
		return nil, err
	}

	if s.ProofType == ProofTypeTrusted {
		metrics.ProverTrustedProofAggregationGeneratedCounter.Add(1)
	} else if s.ProofType == ProofTypeSgx {
		metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)
	}

	return &BatchProofs{
		ProofResponses: items,
		BatchProof:     batchProof,
		Tier:           s.Tier(),
		BlockIDs:       batchIDs,
	}, nil
}

// Tier implements the ProofProducer interface.
func (s *TrustedProofProducer) Tier() uint16 {
	return encoding.TierDeprecated
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *TrustedProofProducer) callProverDaemon(
	ctx context.Context,
	opts ProofRequestOptions,
	requestAt time.Time,
) ([]byte, error) {
	var (
		proof []byte
	)

	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	output, err := s.requestProof(ctx, opts)
	if err != nil {
		log.Error(
			"Failed to request proof",
			"batchID", opts.PacayaOptions().BatchID,
			"error", err,
			"proofType", s.ProofType,
			"endpoint", s.RaikoHostEndpoint,
		)
		return nil, err
	}

	if output == nil {
		log.Info(
			"Proof generating",
			"batchID", opts.PacayaOptions().BatchID,
			"time", time.Since(requestAt),
			"proofType", s.ProofType,
			"producer", "TrustedProofProducer",
		)
		return nil, errProofGenerating
	}

	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, ErrProofInProgress
	}
	if output.Data.Status == StatusRegistered {
		return nil, ErrRetry
	}

	if len(output.Data.Proof.Proof) == 0 {
		return nil, errEmptyProof
	}
	proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])

	log.Info(
		"Proof generated",
		"batchID", opts.PacayaOptions().BatchID,
		"time", time.Since(requestAt),
		"proofType", s.ProofType,
		"producer", "TrustedProofProducer",
	)
	if s.ProofType == ProofTypeTrusted {
		metrics.ProverTrustedProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
	} else if s.ProofType == ProofTypeSgx {
		metrics.ProverSgxProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
	}

	return proof, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *TrustedProofProducer) requestProof(
	ctx context.Context,
	opts ProofRequestOptions,
) (*RaikoRequestProofBodyResponseV2, error) {
	if !opts.IsPacaya() {
		return nil, fmt.Errorf("current proposal is not Pacaya proposal")
	}
	reqBody := RaikoRequestProofBody{
		Type:   s.ProofType,
		Block:  opts.PacayaOptions().BatchID,
		Prover: opts.PacayaOptions().ProverAddress.Hex()[2:],
		SGX: &SGXRequestProofBodyParam{
			Setup:     false,
			Bootstrap: false,
			Prove:     true,
		},
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", s.RaikoHostEndpoint+"/v2/proof", bytes.NewBuffer(jsonValue))
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
		return nil, fmt.Errorf(
			"failed to request proof, id: %d, statusCode: %d", opts.PacayaOptions().BatchID, res.StatusCode,
		)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Proof generation output",
		"batchID", opts.PacayaOptions().BatchID,
		"proofType", s.ProofType,
		"output", string(resBytes),
	)

	var output RaikoRequestProofBodyResponseV2
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		return nil, fmt.Errorf("failed to get proof, err: %s, msg: %s, type: %s, id: %d",
			output.Error,
			output.ErrorMessage,
			output.ProofType,
			opts.PacayaOptions().BatchID,
		)
	}

	return &output, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *TrustedProofProducer) requestBatchProof(
	ctx context.Context,
	batchIDs []*big.Int,
	proverAddress common.Address,
	graffiti string,
	requestAt time.Time,
) ([]byte, error) {
	var (
		proof []byte
	)

	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	batches := make([][2]*big.Int, len(batchIDs))
	for i := range batchIDs {
		batches[i][0] = batchIDs[i]
	}
	reqBody := RaikoRequestProofBodyV3{
		Type:     s.ProofType,
		Blocks:   batches,
		Prover:   proverAddress.Hex()[2:],
		Graffiti: graffiti,
		SGX: &SGXRequestProofBodyParam{
			Setup:     false,
			Bootstrap: false,
			Prove:     true,
		},
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Send batch proof generation request",
		"batchIDs", batchIDs,
		"proofType", s.ProofType,
		"input", string(jsonValue),
	)

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		s.RaikoHostEndpoint+"/v3/proof",
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
		return nil, fmt.Errorf("failed to request batch proof, ids: %v, statusCode: %d", batchIDs, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Batch proof generation output",
		"batchIDs", batchIDs,
		"proofType", s.ProofType,
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
			batchIDs,
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
	proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])

	log.Info(
		"Batch proof generated",
		"batchIDs", batchIDs,
		"time", time.Since(requestAt),
		"producer", "TrustedProofProducer",
	)

	if s.ProofType == ProofTypeTrusted {
		metrics.ProverTrustedAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
	} else if s.ProofType == ProofTypeSgx {
		metrics.ProverSGXAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
	}

	return proof, nil
}
