package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// SGXProofProducer generates a SGX proof for the given block.
type SGXProofProducer struct {
	RaikoHostEndpoint   string    // a prover RPC endpoint
	ProofType           ProofType // Proof type
	JWT                 string    // JWT provided by Raiko
	Dummy               bool
	RaikoRequestTimeout time.Duration
	DummyProofProducer
}

// RaikoRequestProofBody represents the JSON body for requesting the proof.
type RaikoRequestProofBody struct {
	Block    *big.Int                    `json:"block_number"`
	Prover   string                      `json:"prover"`
	Graffiti string                      `json:"graffiti"`
	Type     ProofType                   `json:"proof_type"`
	SGX      *SGXRequestProofBodyParam   `json:"sgx"`
	RISC0    *RISC0RequestProofBodyParam `json:"risc0"`
	SP1      *SP1RequestProofBodyParam   `json:"sp1"`
	ZkAny    *ZkAnyRequestProofBodyParam `json:"zk_any"`
}

// RaikoRequestProofBodyV3 represents the JSON body for requesting the proof.
type RaikoRequestProofBodyV3 struct {
	Blocks   [][2]*big.Int               `json:"block_numbers"`
	Prover   string                      `json:"prover"`
	Graffiti string                      `json:"graffiti"`
	Type     ProofType                   `json:"proof_type"`
	SGX      *SGXRequestProofBodyParam   `json:"sgx"`
	RISC0    *RISC0RequestProofBodyParam `json:"risc0"`
	SP1      *SP1RequestProofBodyParam   `json:"sp1"`
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

// SP1RequestProofBodyParam represents the JSON body of RaikoRequestProofBody's `sp1` field.
type SP1RequestProofBodyParam struct {
	Recursion string `json:"recursion"`
	Prover    string `json:"prover"`
	Verify    bool   `json:"verify"`
}

// ZkAnyRequestProofBodyParam represents the JSON body of RaikoRequestProofBody's `zk_any` field.
type ZkAnyRequestProofBodyParam struct {
	Aggregation bool `json:"aggregation"`
}

// RaikoRequestProofBodyResponse represents the JSON body of the response of the proof requests.
type RaikoRequestProofBodyResponse struct {
	Data         *RaikoProofData `json:"data"`
	ErrorMessage string          `json:"message"`
}

type RaikoProofData struct {
	Proof  string `json:"proof"` //nolint:revive,stylecheck
	Status string `json:"status"`
}

// RequestProof implements the ProofProducer interface.
func (s *SGXProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request sgx proof from raiko-host service",
		"blockID", blockID,
		"coinbase", meta.Ontake().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	if s.Dummy {
		return s.DummyProofProducer.RequestProof(opts, blockID, meta, s.Tier(), requestAt)
	}

	proof, err := s.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
	}

	metrics.ProverSgxProofGeneratedCounter.Add(1)

	return &ProofResponse{
		BlockID: blockID,
		Meta:    meta,
		Proof:   proof,
		Opts:    opts,
		Tier:    s.Tier(),
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *SGXProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	log.Info(
		"Aggregate sgx batch proofs from raiko-host service",
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
	)
	if err != nil {
		return nil, err
	}

	metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)

	return &BatchProofs{
		ProofResponses: items,
		BatchProof:     batchProof,
		Tier:           s.Tier(),
		BlockIDs:       blockIDs,
		ProofType:      ProofTypeSgx,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (s *SGXProofProducer) RequestCancel(
	ctx context.Context,
	opts ProofRequestOptions,
) error {
	if opts.IsPacaya() {
		return fmt.Errorf("sgx proof cancellation is not supported for Pacaya fork")
	}

	res, err := requestHTTPProofResponse[RaikoRequestProofBody](
		ctx,
		s.RaikoHostEndpoint+"/v2/proof/cancel",
		s.JWT,
		RaikoRequestProofBody{
			Type:     s.ProofType,
			Block:    opts.OntakeOptions().BlockID,
			Prover:   opts.OntakeOptions().ProverAddress.Hex()[2:],
			Graffiti: opts.OntakeOptions().Graffiti,
			SGX: &SGXRequestProofBodyParam{
				Setup:     false,
				Bootstrap: false,
				Prove:     true,
			},
		})
	if err != nil {
		return err
	}
	defer res.Body.Close()

	return nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *SGXProofProducer) requestBatchProof(
	ctx context.Context,
	blockIDs []*big.Int,
	proverAddress common.Address,
	graffiti string,
	requestAt time.Time,
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
		Type:     s.ProofType,
		Blocks:   blocks,
		Prover:   proverAddress.Hex()[2:],
		Graffiti: graffiti,
		SGX: &SGXRequestProofBodyParam{
			Setup:     false,
			Bootstrap: false,
			Prove:     true,
		},
	}

	output, err := requestHTTPProof[RaikoRequestProofBodyV3, RaikoRequestProofBodyResponseV2](
		ctx,
		s.RaikoHostEndpoint+"/v3/proof",
		s.JWT,
		RaikoRequestProofBodyV3{
			Type:     s.ProofType,
			Blocks:   blocks,
			Prover:   proverAddress.Hex()[2:],
			Graffiti: graffiti,
			SGX: &SGXRequestProofBodyParam{
				Setup:     false,
				Bootstrap: false,
				Prove:     true,
			},
		},
	)
	if err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		return nil, fmt.Errorf("failed to get sgx batch proof, err: %s, msg: %s",
			output.Error,
			output.ErrorMessage,
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
		"blockIDs", blockIDs,
		"time", time.Since(requestAt),
		"producer", "SGXProofProducer",
	)
	metrics.ProverSGXAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))

	return proof, nil
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *SGXProofProducer) callProverDaemon(
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
			"blockID", opts.OntakeOptions().BlockID,
			"error", err,
			"endpoint", s.RaikoHostEndpoint,
		)
		return nil, err
	}

	if output == nil {
		log.Info(
			"Proof generating",
			"blockID", opts.OntakeOptions().BlockID,
			"time", time.Since(requestAt),
			"producer", "SGXProofProducer",
		)
		return nil, errProofGenerating
	}

	if output.Data.Status == ErrProofInProgress.Error() {
		return nil, ErrProofInProgress
	}
	if output.Data.Status == StatusRegistered {
		return nil, ErrRetry
	}

	// Raiko returns "" as proof when proof type is native,
	// so we just convert "" to bytes
	if s.ProofType == ProofTypeSgxCPU {
		proof = common.Hex2Bytes(output.Data.Proof.Proof)
	} else {
		if len(output.Data.Proof.Proof) == 0 {
			return nil, errEmptyProof
		}
		proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])
	}

	log.Info(
		"Proof generated",
		"blockID", opts.OntakeOptions().BlockID,
		"time", time.Since(requestAt),
		"producer", "SGXProofProducer",
	)
	metrics.ProverSgxProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))

	return proof, nil
}

// requestProof sends a RPC request to proverd to try to get the requested proof.
func (s *SGXProofProducer) requestProof(
	ctx context.Context,
	opts ProofRequestOptions,
) (*RaikoRequestProofBodyResponseV2, error) {
	if opts.IsPacaya() {
		return nil, fmt.Errorf("sgx proof generation is not supported for Pacaya fork")
	}

	output, err := requestHTTPProof[RaikoRequestProofBody, RaikoRequestProofBodyResponseV2](
		ctx,
		s.RaikoHostEndpoint+"/v2/proof",
		s.JWT,
		RaikoRequestProofBody{
			Type:     s.ProofType,
			Block:    opts.OntakeOptions().BlockID,
			Prover:   opts.OntakeOptions().ProverAddress.Hex()[2:],
			Graffiti: opts.OntakeOptions().Graffiti,
			SGX: &SGXRequestProofBodyParam{
				Setup:     false,
				Bootstrap: false,
				Prove:     true,
			},
		},
	)
	if err != nil {
		return nil, err
	}

	if len(output.ErrorMessage) > 0 || len(output.Error) > 0 {
		return nil, fmt.Errorf("failed to get sgx proof,err: %s, msg: %s", output.Error, output.ErrorMessage)
	}

	return output, nil
}

// Tier implements the ProofProducer interface.
func (s *SGXProofProducer) Tier() uint16 {
	return encoding.TierSgxID
}
