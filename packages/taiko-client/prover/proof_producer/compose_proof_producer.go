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
	ProofType           ProofType
	Dummy               bool
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
		proof     []byte
		proofType ProofType
		batches   = []*RaikoBatches{{BatchID: batchID, L1InclusionBlockNumber: meta.GetRawBlockHeight()}}
		g         = new(errgroup.Group)
	)

	g.Go(func() error {
		// SGX proof request raiko-host service
		// Note that - unlike `taiko-mono` upstream - we don't request the SGXGeth in Surge,
		// instead we request the normal SGX proof
		if s.Dummy {
			log.Debug("Dummy proof producer requested SGX proof", "batchID", batchID)

			// The following line is a no-op; this is just to showcase the dummy proof producer
			_, _ = s.DummyProofProducer.RequestProof(opts, batchID, meta, requestAt)
			return nil
		}

		// By design we drop the SGX proof response in the following line because at this point we
		// only need to record that it succeeded and we actually collect it during the next aggregation step
		if _, err := s.requestBatchProof(
			ctx,
			batches,
			opts.GetProverAddress(),
			false,
			ProofTypeSgx,
			requestAt,
			opts.PacayaOptions().IsRethSGXProofGenerated,
		); err != nil {
			return err
		}

		// Note: we mark the `IsRethSGXProofGenerated` with true to record if it is first time generated
		opts.PacayaOptions().IsRethSGXProofGenerated = true
		return nil
	})
	g.Go(func() error {
		// ZK proof request raiko-host service
		// Note that s.ProofType here is always ProofTypeZKAny in Surge
		if s.Dummy {
			log.Debug("Dummy proof producer requested ZK proof", "batchID", batchID)

			// For the dummy proof producer, we just use the sp1 proof type (as zk_any would break the logic down the line)
			proofType = ProofTypeZKSP1
			if resp, err := s.DummyProofProducer.RequestProof(opts, batchID, meta, requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}

			return nil
		}

		resp, err := s.requestBatchProof(
			ctx,
			batches,
			opts.GetProverAddress(),
			false,
			s.ProofType,
			requestAt,
			opts.PacayaOptions().IsRethZKProofGenerated,
		)
		if err != nil {
			return err
		}

		proofType = resp.ProofType
		// Note: we mark the `IsRethZKProofGenerated` with true to record if it is first time generated
		opts.PacayaOptions().IsRethZKProofGenerated = true
		// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
		if ProofTypeZKSP1 != proofType {
			proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
		}

		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &ProofResponse{
		BatchID:   batchID,
		Meta:      meta,
		Proof:     proof,
		Opts:      opts,
		ProofType: proofType,
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
	// TODO(@jmadibekov): manually test the scenario when risc0 and sp1 proofs are mixed in the same group of batches.
	firstItem := items[0]
	proofType := firstItem.ProofType
	verifier, exist := s.Verifiers[proofType]
	if !exist {
		return nil, fmt.Errorf("unknown proof type from raiko %s", proofType)
	}
	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"proofType", proofType,
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
		if s.Dummy {
			log.Debug("Dummy proof producer requested SGX batch proof aggregation", "batchSize", len(items))

			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, ProofTypeSgx)
			sgxBatchProofs = resp.BatchProof
			return nil
		}

		resp, err := s.requestBatchProof(
			ctx,
			batches,
			firstItem.Opts.GetProverAddress(),
			true,
			ProofTypeSgx,
			requestAt,
			firstItem.Opts.PacayaOptions().IsRethSGXProofAggregationGenerated,
		)
		if err != nil {
			return err
		}

		// Note: we mark the `IsRethSGXProofAggregationGenerated` in the first item with true
		// to record if it is first time generated
		firstItem.Opts.PacayaOptions().IsRethSGXProofAggregationGenerated = true
		sgxBatchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])

		return nil
	})
	g.Go(func() error {
		if s.Dummy {
			log.Debug("Dummy proof producer requested ZK batch proof aggregation", "batchSize", len(items))

			proofType = s.ProofType
			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, s.ProofType)
			batchProofs = resp.BatchProof
			return nil
		}

		resp, err := s.requestBatchProof(
			ctx,
			batches,
			firstItem.Opts.GetProverAddress(),
			true,
			proofType,
			requestAt,
			firstItem.Opts.PacayaOptions().IsRethZKProofAggregationGenerated,
		)
		if err != nil {
			return err
		}

		// Note: we mark the `IsRethZKProofAggregationGenerated` in the first item with true
		// to record if it is first time generated
		firstItem.Opts.PacayaOptions().IsRethZKProofAggregationGenerated = true
		batchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])

		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:   items,
		BatchProof:       batchProofs,
		BatchIDs:         batchIDs,
		ProofType:        proofType,
		Verifier:         verifier,
		SgxBatchProof:    sgxBatchProofs,
		SgxProofVerifier: s.Verifiers[ProofTypeSgx],
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
	if proofType == ProofTypeSgx {
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
