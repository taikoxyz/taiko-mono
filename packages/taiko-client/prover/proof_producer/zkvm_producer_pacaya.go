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

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ZKvmProofProducerPacaya generates a ZK proof for the given block.
type ZKvmProofProducerPacaya struct {
	Verifiers           map[string]common.Address
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
	TrustedProducer     TrustedProofProducer
}

func (z *ZKvmProofProducerPacaya) RequestProof(
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
		"Request zk proof from raiko-host service",
		"batchID", batchID,
		"zkType", ZKProofTypeAny,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	g := new(errgroup.Group)

	g.Go(func() error {
		if _, err := z.TrustedProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
			return err
		}
		return nil
	})

	proof, proofType, err := z.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
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
func (z *ZKvmProofProducerPacaya) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	zkType := items[0].ProofType
	verifier, exist := z.Verifiers[zkType]
	if !exist {
		return nil, fmt.Errorf("unknown zk proof type from raiko %s", zkType)
	}
	log.Info(
		"Aggregate zkvm batch proofs from raiko-host service",
		"zkType", zkType,
		"batchSize", len(items),
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)
	var (
		g                  = new(errgroup.Group)
		trustedBatchProofs *BatchProofs
		zkBatchProofs      []byte
		err                error
		batchIDs           = make([]*big.Int, len(items))
	)
	for i, item := range items {
		batchIDs[i] = item.Meta.Pacaya().GetBatchID()
	}
	g.Go(func() error {
		if trustedBatchProofs, err = z.TrustedProducer.Aggregate(ctx, items, requestAt); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if zkBatchProofs, err = z.requestBatchProof(
			ctx,
			batchIDs,
			items[0].Opts.GetProverAddress(),
			items[0].Opts.GetGraffiti(),
			requestAt,
			zkType,
		); err != nil {
			return err
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:       items,
		BatchProof:           zkBatchProofs,
		Tier:                 z.Tier(),
		BlockIDs:             batchIDs,
		ProofType:            zkType,
		Verifier:             verifier,
		TrustedBatchProof:    trustedBatchProofs.BatchProof,
		TrustedProofVerifier: trustedBatchProofs.Verifier,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (z *ZKvmProofProducerPacaya) RequestCancel(
	ctx context.Context,
	opts ProofRequestOptions,
) error {
	// TODO: waiting raiko api specific
	return nil
}

// Tier implements the ProofProducer interface.
func (z *ZKvmProofProducerPacaya) Tier() uint16 {
	return encoding.TierDeprecated
}

// callProverDaemon keeps polling the proverd service to get the requested proof.
func (s *ZKvmProofProducerPacaya) callProverDaemon(
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
			"batchID", opts.PacayaOptions().BatchID,
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

	// TODO: waiting raiko api specific
	if !opts.OntakeOptions().Compressed {
		if len(output.Data.Proof.Proof) == 0 {
			return nil, "", errEmptyProof
		}
		proof = common.Hex2Bytes(output.Data.Proof.Proof[2:])
	}
	log.Info(
		"Proof generated",
		"batchID", opts.PacayaOptions().BatchID,
		"zkType", output.ProofType,
		"time", time.Since(requestAt),
		"producer", "ZKvmProofProducerPacaya",
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
func (z *ZKvmProofProducerPacaya) requestProof(
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

	req, err := http.NewRequestWithContext(ctx, "POST", z.RaikoHostEndpoint+"/v2/proof", bytes.NewBuffer(jsonValue))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(z.JWT) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(z.JWT)))
	}

	log.Debug(
		"Send proof generation request",
		"batchID", opts.PacayaOptions().BatchID,
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
			opts.PacayaOptions().BatchID,
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

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (z *ZKvmProofProducerPacaya) requestBatchProof(
	ctx context.Context,
	batchIDs []*big.Int,
	proverAddress common.Address,
	graffiti string,
	requestAt time.Time,
	zkType string,
) ([]byte, error) {
	var (
		proof []byte
	)

	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, z.RaikoRequestTimeout)
	defer cancel()

	blocks := make([][2]*big.Int, len(batchIDs))
	for i := range batchIDs {
		blocks[i][0] = batchIDs[i]
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
		"batchIDs", batchIDs,
		"zkProofType", zkType,
		"input", string(jsonValue),
	)

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		z.RaikoHostEndpoint+"/v3/proof",
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
		return nil, fmt.Errorf("failed to request batch proof, ids: %v, statusCode: %d", batchIDs, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug(
		"Batch proof generation output",
		"batchIDs", batchIDs,
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
		"batchIDs", batchIDs,
		"zkType", zkType,
		"time", time.Since(requestAt),
		"producer", "ZKvmProofProducerPacaya",
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
