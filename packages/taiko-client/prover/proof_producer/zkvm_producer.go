package producer

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
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
	ZKProofTypeR0  = "risc0"
	ZKProofTypeSP1 = "sp1"
	ZKProofTypeAny = "zk_any"
)

var (
	ErrProofInProgress = errors.New("work_in_progress")
	ErrRetry           = errors.New("retry")
	ErrZkAnyNotDrawn   = errors.New("zk_any_not_drawn")
	StatusRegistered   = "registered"
)

// RaikoRequestProofBodyResponseV2 represents the JSON body of the response of the proof requests.
type RaikoRequestProofBodyResponseV2 struct {
	Data         *RaikoProofDataV2 `json:"data"`
	ErrorMessage string            `json:"message"`
	Error        string            `json:"error"`
	ProofType    string            `json:"proof_type"`
}

type RaikoProofDataV2 struct {
	Proof  *ProofDataV2 `json:"proof"` //nolint:revive,stylecheck
	Status string       `json:"status"`
}

type ProofDataV2 struct {
	KzgProof string `json:"kzg_proof"`
	Proof    string `json:"proof"`
	Quote    string `json:"quote"`
}

// ZKvmProofProducer generates a ZK proof for the given block.
type ZKvmProofProducer struct {
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
	Dummy               bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ZKvmProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	if meta.IsPacaya() {
		return nil, fmt.Errorf("zk proof generation is not supported for Pacaya")
	}

	log.Info(
		"Request zk proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.Ontake().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, blockID, meta, s.Tier(), requestAt)
	}

	proof, proofType, err := s.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
	}

	return &ProofResponse{
		BlockID:   blockID,
		Meta:      meta,
		Proof:     proof,
		Opts:      opts,
		Tier:      s.Tier(),
		ProofType: proofType,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (s *ZKvmProofProducer) RequestCancel(
	ctx context.Context,
	opts ProofRequestOptions,
) error {
	return s.requestCancel(ctx, opts)
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *ZKvmProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	zkType := items[0].ProofType
	log.Info(
		"Aggregate zkvm batch proofs from raiko-host service",
		"zkType", zkType,
		"batchSize", len(items),
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}

	blockIDs := make([]*big.Int, len(items))
	for i, item := range items {
		blockIDs[i] = item.Meta.Ontake().GetBlockID()
	}
	batchProof, err := s.requestBatchProof(
		ctx,
		blockIDs,
		items[0].Opts.GetProverAddress(),
		items[0].Opts.GetGraffiti(),
		requestAt,
		zkType,
	)
	if err != nil {
		return nil, err
	}

	return &BatchProofs{
		ProofResponses: items,
		BatchProof:     batchProof,
		Tier:           s.Tier(),
		BlockIDs:       blockIDs,
		ProofType:      zkType,
	}, nil
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *ZKvmProofProducer) callProverDaemon(
	ctx context.Context,
	opts ProofRequestOptions,
	requestAt time.Time,
) ([]byte, string, error) {
	var (
		proof []byte
	)

	zkCtx, zkCancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer zkCancel()

	output, err := s.requestProof(zkCtx, opts)
	if err != nil {
		log.Error(
			"Failed to request proof",
			"blockID", opts.OntakeOptions().BlockID,
			"error", err,
			"endpoint", s.RaikoHostEndpoint,
		)
		return nil, "", err
	}

	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, "", ErrProofInProgress
	}
	if output.Data.Status == StatusRegistered {
		return nil, "", ErrRetry
	}

	if !opts.OntakeOptions().Compressed {
		if len(output.Data.Proof.Proof) == 0 {
			return nil, "", errEmptyProof
		}
		proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])
	}
	log.Info(
		"Proof generated",
		"blockID", opts.OntakeOptions().BlockID,
		"zkType", output.ProofType,
		"time", time.Since(requestAt),
		"producer", "ZKvmProofProducer",
	)
	if output.ProofType == ZKProofTypeR0 {
		metrics.ProverR0ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
		metrics.ProverR0ProofGeneratedCounter.Add(1)
	} else if output.ProofType == ZKProofTypeSP1 {
		metrics.ProverSP1ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
		metrics.ProverSp1ProofGeneratedCounter.Add(1)
	}

	return proof, output.ProofType, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *ZKvmProofProducer) requestProof(
	ctx context.Context,
	opts ProofRequestOptions,
) (*RaikoRequestProofBodyResponseV2, error) {
	reqBody := RaikoRequestProofBody{
		Type:     ZKProofTypeAny,
		Block:    opts.OntakeOptions().BlockID,
		Prover:   opts.OntakeOptions().ProverAddress.Hex()[2:],
		Graffiti: opts.OntakeOptions().Graffiti,
		ZkAny: &ZkAnyRequestProofBodyParam{
			Aggregation: opts.OntakeOptions().Compressed,
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

	log.Debug(
		"Send proof generation request",
		"blockID", opts.OntakeOptions().BlockID,
		"zkProofType", ZKProofTypeAny,
		"input", string(jsonValue),
	)

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf(
			"failed to request proof, id: %d, statusCode: %d",
			opts.OntakeOptions().BlockID,
			res.StatusCode,
		)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Proof generation output",
		"blockID", opts.OntakeOptions().BlockID,
		"zkProofType", ZKProofTypeAny,
		"output", string(resBytes),
	)
	var output RaikoRequestProofBodyResponseV2
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		log.Error("Failed to get zk proof",
			"err", output.Error,
			"msg", output.ErrorMessage,
			"zkType", ZKProofTypeAny,
		)
		return nil, errors.New(output.Error)
	}

	return &output, nil
}

func (s *ZKvmProofProducer) requestCancel(
	ctx context.Context,
	opts ProofRequestOptions,
) error {
	if opts.IsPacaya() {
		return fmt.Errorf("proof cancellation is not supported for Pacaya fork")
	}

	reqBody := RaikoRequestProofBody{
		Type:     ZKProofTypeAny,
		Block:    opts.OntakeOptions().BlockID,
		Prover:   opts.OntakeOptions().ProverAddress.Hex()[2:],
		Graffiti: opts.OntakeOptions().Graffiti,
		ZkAny: &ZkAnyRequestProofBodyParam{
			Aggregation: opts.OntakeOptions().Compressed,
		},
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		s.RaikoHostEndpoint+"/v2/proof/cancel",
		bytes.NewBuffer(jsonValue),
	)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(s.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(s.JWT)))
	}

	res, err := client.Do(req)
	if err != nil {
		return err
	}

	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to cancel requesting proof, statusCode: %d", res.StatusCode)
	}

	return nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *ZKvmProofProducer) requestBatchProof(
	ctx context.Context,
	blockIDs []*big.Int,
	proverAddress common.Address,
	graffiti string,
	requestAt time.Time,
	zkType string,
) ([]byte, error) {
	var (
		proof []byte
	)

	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	blocks := make([][2]*big.Int, len(blockIDs))
	for i := range blockIDs {
		blocks[i][0] = blockIDs[i]
	}

	reqBody := RaikoRequestProofBodyV3{
		Type:     zkType,
		Blocks:   blocks,
		Prover:   proverAddress.Hex()[2:],
		Graffiti: graffiti,
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Send batch proof generation request",
		"blockIDs", blockIDs,
		"zkProofType", zkType,
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
		return nil, fmt.Errorf("failed to request batch proof, ids: %v, statusCode: %d", blockIDs, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Batch proof generation output",
		"blockIDs", blockIDs,
		"zkProofType", zkType,
		"output", string(resBytes),
	)

	var output RaikoRequestProofBodyResponseV2
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		log.Error("Failed to get zk batch proof",
			"err", output.Error,
			"msg", output.ErrorMessage,
			"zkType", zkType,
		)
		return nil, errors.New(output.Error)
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

	if output.Data.Proof == nil || len(output.Data.Proof.Proof) == 0 {
		return nil, errEmptyProof
	}
	proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])

	log.Info(
		"Batch proof generated",
		"blockIDs", blockIDs,
		"zkType", zkType,
		"time", time.Since(requestAt),
		"producer", "ZKvmProofProducer",
	)

	if zkType == ZKProofTypeR0 {
		metrics.ProverR0AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
		metrics.ProverR0ProofAggregationGeneratedCounter.Add(1)
	} else if zkType == ZKProofTypeSP1 {
		metrics.ProverSP1AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
		metrics.ProverSp1ProofAggregationGeneratedCounter.Add(1)
	}

	return proof, nil
}

// Tier implements the ProofProducer interface.
func (s *ZKvmProofProducer) Tier() uint16 {
	return encoding.TierZkVMSp1ID
}
