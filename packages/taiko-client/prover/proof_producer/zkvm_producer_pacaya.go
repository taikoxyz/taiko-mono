package producer

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"math/big"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

// ZKvmProofProducerPacaya generates a ZK proof for the given block.
type ZKvmProofProducerPacaya struct {
	Verifiers           map[string]common.Address
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko
}

func (z *ZKvmProofProducerPacaya) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	if !meta.IsPacaya() {
		return nil, fmt.Errorf("current proposal is not Pacaya proposal")
	}

	log.Info(
		"Request zk proof from raiko-host service",
		"batchID", blockID,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	proof, proofType, err := z.callProverDaemon(ctx, opts, requestAt)
	if err != nil {
		return nil, err
	}

	return &ProofResponse{
		BlockID:   blockID,
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
	log.Info(
		"Aggregate zkvm batch proofs from raiko-host service",
		"zkType", zkType,
		"batchSize", len(items),
		"firstID", items[0].BlockID,
		"lastID", items[len(items)-1].BlockID,
		"time", time.Since(requestAt),
	)
	verifier, exist := z.Verifiers[zkType]
	if !exist {
		return nil, fmt.Errorf("unknown proof type from raiko %s", zkType)
	}
	batchIDs := make([]*big.Int, len(items))
	for i, item := range items {
		batchIDs[i] = item.Meta.Pacaya().GetBatchID()
	}

	return &BatchProofs{
		ProofResponses: items,
		BatchProof:     batchProof,
		Tier:           s.Tier(),
		BlockIDs:       batchIDs,
		ProofType:      zkType,
		Verifier:       verifier,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (z *ZKvmProofProducerPacaya) RequestCancel(
	ctx context.Context,
	opts ProofRequestOptions,
) error {
	if !opts.IsPacaya() {
		return fmt.Errorf("only support proof cancellation for Pacaya fork")
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

// Tier implements the ProofProducer interface.
func (z *ZKvmProofProducerPacaya) Tier() uint16 {
	return encoding.TierOptimisticID
}
