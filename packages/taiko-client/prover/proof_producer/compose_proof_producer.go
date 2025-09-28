package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// RaikoBatches represents the JSON body of RaikoRequestProofBodyV3Pacaya's `Batches` field.
type RaikoBatches struct {
	BatchID                *big.Int `json:"batch_id"`
	L1InclusionBlockNumber *big.Int `json:"l1_inclusion_block_number"`
}

// RaikoRequestProofBodyV3Pacaya represents the JSON body for requesting the proof.
type RaikoRequestProofBodyV3Pacaya struct {
	Batches   []*RaikoBatches `json:"batches"`
	Prover    string          `json:"prover"`
	Aggregate bool            `json:"aggregate"`
	Type      ProofType       `json:"proof_type"`
}

// ComposeProofProducer generates a compose proof for the given block.
type ComposeProofProducer struct {
	Verifiers map[ProofType]common.Address

	RaikoSGXHostEndpoint  string
	RaikoZKVMHostEndpoint string

	RaikoRequestTimeout time.Duration
	JWT                 string // JWT provided by Raiko

	Dummy bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ComposeProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	if !meta.IsPacaya() {
		return nil, fmt.Errorf("current proposal (%d) is not a Pacaya proposal", batchID)
	}

	log.Info(
		"Request SGX + ZK proofs from raiko-host service",
		"batchID", batchID,
		"coinbase", meta.Pacaya().GetCoinbase(),
		"time", time.Since(requestAt),
	)

	var (
		proof        []byte
		zkProofType  ProofType
		sgxProofType ProofType
		batches      = []*RaikoBatches{{BatchID: batchID, L1InclusionBlockNumber: meta.GetRawBlockHeight()}}
		g            = new(errgroup.Group)
	)

	g.Go(func() error {
		// => SGX proof request raiko-host service
		resp, err := s.requestBatchProof(
			ctx,
			batches,
			opts.GetProverAddress(),
			false,
			ProofTypeSgxAny,
			requestAt,
			opts.PacayaOptions().IsSGXProofGenerated,
		)
		if err != nil {
			return err
		}

		sgxProofType = resp.ProofType

		// Note: we mark the `IsSGXProofGenerated` with true to record if it is first time generated
		opts.PacayaOptions().IsSGXProofGenerated = true
		return nil
	})
	g.Go(func() error {
		// => ZK proof request raiko-host service
		resp, err := s.requestBatchProof(
			ctx,
			batches,
			opts.GetProverAddress(),
			false,
			ProofTypeZKAny,
			requestAt,
			opts.PacayaOptions().IsZKProofGenerated,
		)
		if err != nil {
			return err
		}

		zkProofType = resp.ProofType
		// Note: we mark the `IsZKProofGenerated` with true to record if it is first time generated
		opts.PacayaOptions().IsZKProofGenerated = true
		// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
		if ProofTypeZKSP1 != zkProofType {
			proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
		}

		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &ProofResponse{
		BatchID:      batchID,
		Meta:         meta,
		Proof:        proof,
		Opts:         opts,
		ZKProofType:  zkProofType,
		SGXProofType: sgxProofType,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *ComposeProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	// TODO(@jmadibekov): manually test the scenario when risc0 and sp1 proofs are mixed
	// in the same group of batches (if that's even possible)
	firstItem := items[0]
	zkProofType := firstItem.ZKProofType
	sgxProofType := firstItem.SGXProofType

	verifier, exist := s.Verifiers[zkProofType]
	if !exist {
		return nil, fmt.Errorf("unknown proof type from raiko %s", zkProofType)
	}
	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"zkProofType", zkProofType,
		"sgxProofType", sgxProofType,
		"batchSize", len(items),
		"firstID", firstItem.BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)
	var (
		sgxBatchProofs []byte
		batchProofs    []byte
		batches        = make([]*RaikoBatches, 0, len(items))
		batchIDs       = make([]*big.Int, 0, len(items))
		g              = new(errgroup.Group)
	)
	for _, item := range items {
		batches = append(batches, &RaikoBatches{
			BatchID:                item.Meta.Pacaya().GetBatchID(),
			L1InclusionBlockNumber: item.Meta.GetRawBlockHeight(),
		})
		batchIDs = append(batchIDs, item.Meta.Pacaya().GetBatchID())
	}
	g.Go(func() error {
		resp, err := s.requestBatchProof(
			ctx,
			batches,
			firstItem.Opts.GetProverAddress(),
			true,
			sgxProofType,
			requestAt,
			firstItem.Opts.PacayaOptions().IsSGXProofAggregationGenerated,
		)
		if err != nil {
			return err
		}

		// Note: we mark the `IsSGXProofAggregationGenerated` in the first item with true
		// to record if it is first time generated
		firstItem.Opts.PacayaOptions().IsSGXProofAggregationGenerated = true
		sgxBatchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])

		return nil
	})
	g.Go(func() error {
		resp, err := s.requestBatchProof(
			ctx,
			batches,
			firstItem.Opts.GetProverAddress(),
			true,
			zkProofType,
			requestAt,
			firstItem.Opts.PacayaOptions().IsZKProofAggregationGenerated,
		)
		if err != nil {
			return err
		}

		// Note: we mark the `IsZKProofAggregationGenerated` in the first item with true
		// to record if it is first time generated
		firstItem.Opts.PacayaOptions().IsZKProofAggregationGenerated = true
		batchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])

		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses: items,
		BatchProof:     batchProofs,
		BatchIDs:       batchIDs,
		ProofType:      zkProofType,
		Verifier:       verifier,

		SgxProofType:     sgxProofType,
		SgxBatchProof:    sgxBatchProofs,
		SgxProofVerifier: s.Verifiers[sgxProofType],
	}, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *ComposeProofProducer) requestBatchProof(
	ctx context.Context,
	batches []*RaikoBatches,
	proverAddress common.Address,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	endpoint := s.RaikoZKVMHostEndpoint
	if proofType == ProofTypeSgxGeth || proofType == ProofTypeSgx || proofType == ProofTypeSgxAny {
		endpoint = s.RaikoSGXHostEndpoint
	}

	log.Debug(
		"Making HTTP request to raiko",
		"endpoint", endpoint+"/v3/proof/batch",
		"request", RaikoRequestProofBodyV3Pacaya{
			Type:      proofType,
			Batches:   batches,
			Prover:    proverAddress.Hex()[2:],
			Aggregate: isAggregation,
		},
	)

	output, err := requestHTTPProof[RaikoRequestProofBodyV3Pacaya, RaikoRequestProofBodyResponseV2](
		ctx,
		endpoint+"/v3/proof/batch",
		s.JWT,
		RaikoRequestProofBodyV3Pacaya{
			Type:      proofType,
			Batches:   batches,
			Prover:    proverAddress.Hex()[2:],
			Aggregate: isAggregation,
		},
	)
	if err != nil {
		log.Debug(
			"Error making HTTP request to raiko",
			"endpoint", endpoint+"/v3/proof/batch",
			"request", RaikoRequestProofBodyV3Pacaya{
				Type:      proofType,
				Batches:   batches,
				Prover:    proverAddress.Hex()[2:],
				Aggregate: isAggregation,
			},
			"error", err,
		)
		return nil, err
	}

	if err := output.Validate(); err != nil {
		log.Debug(
			"Proof output validation result",
			"start", batches[0].BatchID,
			"end", batches[len(batches)-1].BatchID,
			"proofType", output.ProofType,
			"err", err,
		)
		return nil, fmt.Errorf("invalid Raiko response(start: %d, end: %d): %w",
			batches[0].BatchID,
			batches[len(batches)-1].BatchID,
			err,
		)
	}

	if !alreadyGenerated {
		proofType = output.ProofType
		log.Info(
			"Batch proof generated",
			"isAggregation", isAggregation,
			"proofType", proofType,
			"start", batches[0].BatchID,
			"end", batches[len(batches)-1].BatchID,
			"time", time.Since(requestAt),
		)
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
