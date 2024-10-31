package producer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"io"
	"math/big"
	"net/http"
	"time"
)

const (
	ProofTypeTdx = "tdx"
	ProofTypeCpu = "native"
)

// AutomataRequestProofBody represents the JSON body for requesting the proof.
type AutomataRequestProofBody struct {
	Block                  *big.Int `json:"block_number"`
	L1InclusionBlockNumber uint64   `json:"l1_inclusion_block_number"`
	Network                string   `json:"network"`
	L1Network              string   `json:"l1_network"`
	Graffiti               string   `json:"graffiti"`
	Prover                 string   `json:"prover"`
	ProofType              string   `json:"proof_type"`
	BlobProofType          string   `json:"blob_proof_type"`
	ProverArgs             string   `json:"prover_args"`
}

// TDXProofProducer generates a TDX proof for the given block.
type TDXProofProducer struct {
	Endpoint       string // a prover RPC endpoint
	ProofType      string
	JWT            string // JWT provided by the Prover
	Dummy          bool
	RequestTimeout time.Duration
	DummyProofProducer
}

func (t *TDXProofProducer) RequestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoBlockMetaData,
	header *types.Header,
	requestAt time.Time,
) (*ProofWithHeader, error) {
	log.Info(
		"Request tdx proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.GetCoinbase(),
		"height", header.Number,
		"hash", header.Hash(),
	)

	if t.Dummy {
		return t.DummyProofProducer.RequestProof(opts, blockID, meta, header, t.Tier(), requestAt)
	}

	proof, err := t.callProver(ctx, opts, meta, requestAt)
	if err != nil {
		return nil, err
	}

	metrics.ProverTdxProofGEneratedCounter.Add(1)

	return &ProofWithHeader{
		BlockID: blockID,
		Meta:    meta,
		Header:  header,
		Proof:   proof,
		Opts:    opts,
		Tier:    t.Tier(),
	}, nil
}

func (t *TDXProofProducer) callProver(
	ctx context.Context,
	opts *ProofRequestOptions,
	meta metadata.TaikoBlockMetaData,
	requestAt time.Time) ([]byte, error) {
	var (
		proof []byte
	)

	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, t.RequestTimeout)
	defer cancel()

	output, err := t.requestProof(ctx, opts, meta)
	if err != nil {
		log.Error("Failed to request proof", "height", opts.BlockID, "error", err, "endpoint", t.Endpoint)
		return nil, err
	}

	if output == nil {
		log.Info(
			"Proof generating",
			"height", opts.BlockID,
			"time", time.Since(requestAt),
			"producer", "TDXProofProducer",
		)
		return nil, errProofGenerating
	}

	proof = common.Hex2Bytes(output.Data[2:])

	log.Info(
		"Proof generated",
		"height", opts.BlockID,
		"time", time.Since(requestAt),
		"producer", "TXDProofProducer",
	)

	return proof, nil
}

func (t *TDXProofProducer) requestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	meta metadata.TaikoBlockMetaData) (*AutomataRequestProofBodyResponse, error) {
	reqBody := AutomataRequestProofBody{
		Block:                  opts.BlockID,
		L1InclusionBlockNumber: meta.GetProposedIn(),
		Network:                "unifi_testnet",
		L1Network:              "localnet",
		Graffiti:               opts.Graffiti,
		Prover:                 opts.ProverAddress.Hex()[2:],
		ProofType:              "Native",
		BlobProofType:          "kzg_versioned_hash",
		ProverArgs:             "",
	}

	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", t.Endpoint+"/v1/get_proof", bytes.NewBuffer(jsonValue))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

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

	log.Debug(
		"Proof generation output",
		"blockID", opts.BlockID,
		"zkType", "tdx",
		"output", string(resBytes),
	)

	var output AutomataRequestProofBodyResponse
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	return &output, nil
}

func (t *TDXProofProducer) RequestCancel(
	_ context.Context,
	_ *ProofRequestOptions) error {
	return nil
}

func (t *TDXProofProducer) Tier() uint16 {
	return encoding.TierTdxID
}
