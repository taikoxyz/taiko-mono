package producer

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

const (
	ProofTypeSgx = "sgx"
	ProofTypeCPU = "native"
)

// SGXProofProducer generates a SGX proof for the given block.
type SGXProofProducer struct {
	RaikoHostEndpoint string // a proverd RPC endpoint
	L1Endpoint        string // a L1 node RPC endpoint
	L1BeaconEndpoint  string // a L1 beacon node RPC endpoint
	L2Endpoint        string // a L2 execution engine's RPC endpoint
	ProofType         string // Proof type
	Dummy             bool
	DummyProofProducer
}

// RaikoRequestProofBody represents the JSON body for requesting the proof.
type RaikoRequestProofBody struct {
	L2RPC       string                     `json:"rpc"`
	L1RPC       string                     `json:"l1_rpc"`
	L1BeaconRPC string                     `json:"beacon_rpc"`
	Block       *big.Int                   `json:"block_number"`
	Prover      string                     `json:"prover"`
	Graffiti    string                     `json:"graffiti"`
	Type        string                     `json:"proof_type"`
	SGX         *SGXRequestProofBodyParam  `json:"sgx"`
	RISC0       RISC0RequestProofBodyParam `json:"risc0"`
}

// SGXRequestProofBodyParam represents the JSON body of RaikoRequestProofBody's `sgx` field.
type SGXRequestProofBodyParam struct {
	Setup     bool `json:"setup"`
	Bootstrap bool `json:"bootstrap"`
	Prove     bool `json:"prove"`
}

// RISC0RequestProofBodyParam represents the JSON body of RaikoRequestProofBody's `risc0` field.
type RISC0RequestProofBodyParam struct {
	Bonsai       bool     `json:"bonsai"`
	Snark        bool     `json:"snark"`
	Profile      bool     `json:"profile"`
	ExecutionPo2 *big.Int `json:"execution_po2"`
}

// SGXRequestProofBodyResponse represents the JSON body of the response of the proof requests.
type SGXRequestProofBodyResponse struct {
	JsonRPC string           `json:"jsonrpc"` //nolint:revive,stylecheck
	ID      *big.Int         `json:"id"`
	Result  *RaikoHostOutput `json:"result"`
	Error   *struct {
		Code    *big.Int `json:"code"`
		Message string   `json:"message"`
	} `json:"error,omitempty"`
}

// RaikoHostOutput represents the JSON body of SGXRequestProofBodyResponse's `result` field.
type RaikoHostOutput struct {
	Proof string `json:"proof"`
}

// RequestProof implements the ProofProducer interface.
func (s *SGXProofProducer) RequestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	header *types.Header,
) (*ProofWithHeader, error) {
	log.Info(
		"Request proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.Coinbase,
		"height", header.Number,
		"hash", header.Hash(),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, blockID, meta, header, s.Tier())
	}

	proof, err := s.callProverDaemon(ctx, opts)
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

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *SGXProofProducer) callProverDaemon(ctx context.Context, opts *ProofRequestOptions) ([]byte, error) {
	var (
		proof []byte
		start = time.Now()
	)
	if err := backoff.Retry(func() error {
		if ctx.Err() != nil {
			return nil
		}
		output, err := s.requestProof(opts)
		if err != nil {
			log.Error("Failed to request proof", "height", opts.BlockID, "error", err, "endpoint", s.RaikoHostEndpoint)
			return err
		}

		if output == nil {
			log.Info(
				"Proof generating",
				"height", opts.BlockID,
				"time", time.Since(start),
				"producer", "SGXProofProducer",
			)
			return errProofGenerating
		}

		log.Debug("Proof generation output", "output", output)

		proof = common.Hex2Bytes(output.Proof[2:])
		log.Info(
			"Proof generated",
			"height", opts.BlockID,
			"time", time.Since(start),
			"producer", "SGXProofProducer",
		)
		return nil
	}, backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx)); err != nil {
		return nil, err
	}

	return proof, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *SGXProofProducer) requestProof(opts *ProofRequestOptions) (*RaikoHostOutput, error) {
	reqBody := RaikoRequestProofBody{
		Type:        s.ProofType,
		Block:       opts.BlockID,
		L2RPC:       s.L2Endpoint,
		L1RPC:       s.L1Endpoint,
		L1BeaconRPC: s.L1BeaconEndpoint,
		Prover:      opts.ProverAddress.Hex()[2:],
		Graffiti:    opts.Graffiti,
		SGX: &SGXRequestProofBodyParam{
			Setup:     false,
			Bootstrap: false,
			Prove:     true,
		},
	}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	res, err := http.Post(s.RaikoHostEndpoint+"/proof", "application/json", bytes.NewBuffer(jsonValue))
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

	var output SGXRequestProofBodyResponse
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if output.Error != nil {
		return nil, errors.New(output.Error.Message)
	}

	return output.Result, nil
}

// Tier implements the ProofProducer interface.
func (s *SGXProofProducer) Tier() uint16 {
	return encoding.TierSgxID
}
