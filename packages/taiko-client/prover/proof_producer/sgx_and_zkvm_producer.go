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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	ZKProofTypeR0  = "risc0"
	ZKProofTypeSP1 = "sp1"
)

var ErrProofInProgress = errors.New("work_in_progress")

// SgxAndZKvmProofProducer generates a ZK proof for the given block.
type SgxAndZKvmProofProducer struct {
	ZKProofType string // ZK Proof type
	SGX         SGXProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *SgxAndZKvmProofProducer) RequestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoBlockMetaData,
	header *types.Header,
) (*ProofWithHeader, error) {
	log.Info(
		"Request proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.GetCoinbase(),
		"height", header.Number,
		"hash", header.Hash(),
	)

	if s.SGX.Dummy {
		return s.SGX.DummyProofProducer.RequestProof(opts, blockID, meta, header, s.Tier())
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

func (s *SgxAndZKvmProofProducer) RequestCancel(
	ctx context.Context,
	opts *ProofRequestOptions,
) error {
	return s.requestCancel(ctx, opts)
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *SgxAndZKvmProofProducer) callProverDaemon(ctx context.Context, opts *ProofRequestOptions) ([]byte, error) {
	var (
		proof []byte
		start = time.Now()
	)

	zkCtx, zkCancel := rpc.CtxWithTimeoutOrDefault(ctx, s.SGX.RaikoRequestTimeout)
	defer zkCancel()

	output, err := s.requestProof(zkCtx, opts)
	if err != nil {
		log.Error("Failed to request proof", "height", opts.BlockID, "error", err, "endpoint", s.SGX.RaikoHostEndpoint)
		return nil, err
	}

	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, ErrProofInProgress
	}

	log.Debug("Proof generation output", "output", output)

	proof = common.Hex2Bytes(output.Data.Proof[2:])
	log.Info(
		"Proof generated",
		"height", opts.BlockID,
		"time", time.Since(start),
		"producer", "SgxAndZKvmProofProducer",
	)

	return proof, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *SgxAndZKvmProofProducer) requestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
) (*RaikoRequestProofBodyResponse, error) {
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
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", s.SGX.RaikoHostEndpoint+"/v2/proof", bytes.NewBuffer(jsonValue))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(s.SGX.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(s.SGX.JWT)))
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

	var output RaikoRequestProofBodyResponse
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 {
		return nil, fmt.Errorf("failed to get proof, msg: %s", output.ErrorMessage)
	}

	return &output, nil
}

func (s *SgxAndZKvmProofProducer) requestCancel(
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
		s.SGX.RaikoHostEndpoint+"/v2/proof/cancel",
		bytes.NewBuffer(jsonValue),
	)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(s.SGX.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(s.SGX.JWT)))
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
func (s *SgxAndZKvmProofProducer) Tier() uint16 {
	return encoding.TierSgxAndZkVMID
}
