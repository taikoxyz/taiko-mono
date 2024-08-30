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
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	ZKProofTypeR0  = "risc0"
	ZKProofTypeSP1 = "sp1"
)

var (
	ErrProofInProgress = errors.New("work_in_progress")
	ErrRetry           = errors.New("retry")
	StatusRegistered   = "registered"
)

// RaikoRequestProofBodyResponseV2 represents the JSON body of the response of the proof requests.
type RaikoRequestProofBodyResponseV2 struct {
	Data         *RaikoProofDataV2 `json:"data"`
	ErrorMessage string            `json:"message"`
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
	ZKProofType         string // ZK Proof type
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
	Dummy               bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ZKvmProofProducer) RequestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoBlockMetaData,
	header *types.Header,
	requestAt time.Time,
) (*ProofWithHeader, error) {
	log.Info(
		"Request zk proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.GetCoinbase(),
		"height", header.Number,
		"hash", header.Hash(),
		"zk type", s.ZKProofType,
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, blockID, meta, header, s.Tier(), requestAt)
	}

	proof, err := s.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
	}

	metrics.ProverSgxProofGeneratedCounter.Add(1)

	return &ProofWithHeader{
		BlockID: blockID,
		Header:  header,
		Meta:    meta,
		Proof:   proof,
		Opts:    opts,
		Tier:    s.Tier(),
	}, nil
}

func (s *ZKvmProofProducer) RequestCancel(
	ctx context.Context,
	opts *ProofRequestOptions,
) error {
	return s.requestCancel(ctx, opts)
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *ZKvmProofProducer) callProverDaemon(
	ctx context.Context,
	opts *ProofRequestOptions,
	requestAt time.Time,
) ([]byte, error) {
	var (
		proof []byte
	)

	zkCtx, zkCancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer zkCancel()

	output, err := s.requestProof(zkCtx, opts)
	if err != nil {
		log.Error("Failed to request proof", "height", opts.BlockID, "error", err, "endpoint", s.RaikoHostEndpoint)
		return nil, err
	}

	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, ErrProofInProgress
	}
	if output.Data.Status == StatusRegistered {
		return nil, ErrRetry
	}

	proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])
	log.Info(
		"Proof generated",
		"height", opts.BlockID,
		"time", time.Since(requestAt),
		"producer", "ZKvmProofProducer",
	)

	return proof, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *ZKvmProofProducer) requestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
) (*RaikoRequestProofBodyResponseV2, error) {
	var reqBody RaikoRequestProofBody
	switch s.ZKProofType {
	case ZKProofTypeSP1:
		reqBody = RaikoRequestProofBody{
			Type:     s.ZKProofType,
			Block:    opts.BlockID,
			Prover:   opts.ProverAddress.Hex()[2:],
			Graffiti: opts.Graffiti,
			SP1: &SP1RequestProofBodyParam{
				Recursion: "plonk",
				Prover:    "network",
			},
		}
	default:
		reqBody = RaikoRequestProofBody{
			Type:     s.ZKProofType,
			Block:    opts.BlockID,
			Prover:   opts.ProverAddress.Hex()[2:],
			Graffiti: opts.Graffiti,
			RISC0: &RISC0RequestProofBodyParam{
				Bonsai:       true,
				Snark:        true,
				Profile:      false,
				ExecutionPo2: big.NewInt(20),
			},
		}
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
		return nil, fmt.Errorf("failed to request proof, id: %d, statusCode: %d", opts.BlockID, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug("Proof generation output", "output", string(resBytes))
	var output RaikoRequestProofBodyResponseV2
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 {
		return nil, fmt.Errorf("failed to get proof, msg: %s", output.ErrorMessage)
	}

	return &output, nil
}

func (s *ZKvmProofProducer) requestCancel(
	ctx context.Context,
	opts *ProofRequestOptions,
) error {
	reqBody := RaikoRequestProofBody{
		Type:     s.ZKProofType,
		Block:    opts.BlockID,
		Prover:   opts.ProverAddress.Hex()[2:],
		Graffiti: opts.Graffiti,
		RISC0: &RISC0RequestProofBodyParam{
			Bonsai:       true,
			Snark:        true,
			Profile:      false,
			ExecutionPo2: big.NewInt(20),
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

// Tier implements the ProofProducer interface.
func (s *ZKvmProofProducer) Tier() uint16 {
	switch s.ZKProofType {
	case ZKProofTypeSP1:
		return encoding.TierZkVMSp1ID
	default:
		return encoding.TierZkVMRisc0ID
	}
}
