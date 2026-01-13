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

type RaikoCheckpoint struct {
	BlockNum  *big.Int `json:"block_number"`
	BlockHash string   `json:"block_hash"`
	StateRoot string   `json:"state_root"`
}

// RaikoProposals represents the JSON body of RaikoRequestProofBodyV3Shasta's `Proposals` field.
type RaikoProposals struct {
	ProposalId             *big.Int         `json:"proposal_id"`
	L1InclusionBlockNumber *big.Int         `json:"l1_inclusion_block_number"`
	L2BlockNumbers         []*big.Int       `json:"l2_block_numbers"`
	Checkpoint             *RaikoCheckpoint `json:"checkpoint"`
	LastAnchorBlockNumber  *big.Int         `json:"last_anchor_block_number"`
}

// RaikoRequestProofBodyV3Shasta represents the JSON body for requesting the proof.
type RaikoRequestProofBodyV3Shasta struct {
	Proposals []*RaikoProposals `json:"proposals"`
	Prover    string            `json:"prover"`
	Aggregate bool              `json:"aggregate"`
	Type      ProofType         `json:"proof_type"`
}

// ComposeProofProducer generates a compose proof for the given block.
type ComposeProofProducer struct {
	// We use Verifiers for Pacaya proof
	Verifiers map[ProofType]common.Address
	// We use VerifierIDs for Shasta proof
	VerifierIDs         map[ProofType]uint8
	RaikoHostEndpoint   string
	RaikoRequestTimeout time.Duration
	ApiKey              string // ApiKey provided by Raiko
	SgxGethProducer     *SgxGethProofProducer
	ProofType           ProofType
	Dummy               bool
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *ComposeProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	proposalID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request proof from raiko-host service",
		"proposalID", proposalID,
		"proofType", s.ProofType,
		"time", time.Since(requestAt),
		"dummy", s.Dummy,
	)

	var (
		proof          []byte
		proofType      ProofType
		g              = new(errgroup.Group)
		rethProofError error
	)

	g.Go(func() error {
		if s.Dummy {
			proofType = s.ProofType
			if resp, err := s.DummyProofProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
				return err
			} else {
				proof = resp.Proof
			}
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				[]ProofRequestOptions{opts},
				[]metadata.TaikoProposalMetaData{meta},
				false,
				s.ProofType,
				requestAt,
				opts.IsRethProofGenerated(),
			); err != nil {
				rethProofError = err
				return err
			} else {
				proofType = resp.ProofType
				// Note: we mark the `IsRethProofGenerated` with true to record if it is first time generated
				if opts.IsShasta() {
					opts.ShastaOptions().RethProofGenerated = true
				} else {
					opts.PacayaOptions().RethProofGenerated = true
				}
				// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
				if ProofTypeZKSP1 != proofType {
					proof = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
				}
			}
		}
		return nil
	})

	g.Go(func() error {
		if _, err := s.SgxGethProducer.RequestProof(ctx, opts, proposalID, meta, requestAt); err != nil {
			return err
		} else {
			// Note: we mark the `IsGethProofGenerated` with true to record if it is the first time generated
			if opts.IsShasta() {
				opts.ShastaOptions().GethProofGenerated = true
			} else {
				opts.PacayaOptions().GethProofGenerated = true
			}
			return nil
		}
	})

	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w and %w", err, rethProofError)
	}

	return &ProofResponse{
		BatchID:   proposalID,
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
	proofType := items[0].ProofType
	isShasta := items[0].Meta.IsShasta()
	var (
		verifierID uint8
		verifier   common.Address
		exist      bool
	)
	if isShasta {
		if verifierID, exist = s.VerifierIDs[proofType]; !exist {
			return nil, fmt.Errorf("unknown proof type from raiko %s", proofType)
		}
	} else {
		if verifier, exist = s.Verifiers[proofType]; !exist {
			return nil, fmt.Errorf("unknown proof type from raiko %s", proofType)
		}
	}

	log.Info(
		"Aggregate batch proofs from raiko-host service",
		"proofType", proofType,
		"batchSize", len(items),
		"firstID", items[0].BatchID,
		"lastID", items[len(items)-1].BatchID,
		"time", time.Since(requestAt),
	)
	var (
		sgxGethBatchProofs *BatchProofs
		batchProofs        []byte
		batchIDs           = make([]*big.Int, 0, len(items))
		opts               = make([]ProofRequestOptions, 0, len(items))
		metas              = make([]metadata.TaikoProposalMetaData, 0, len(items))
		g                  = new(errgroup.Group)
		err                error
	)
	for _, item := range items {
		opts = append(opts, item.Opts)
		metas = append(metas, item.Meta)
		batchIDs = append(batchIDs, item.Meta.GetProposalID())
	}
	g.Go(func() error {
		if sgxGethBatchProofs, err = s.SgxGethProducer.Aggregate(ctx, items, requestAt); err != nil {
			return err
		} else {
			// Note: we mark the `IsGethProofAggregationGenerated` in the first item with true
			// to record if it is first time generated
			if items[0].Opts.IsShasta() {
				items[0].Opts.ShastaOptions().GethProofAggregationGenerated = true
			} else {
				items[0].Opts.PacayaOptions().GethProofAggregationGenerated = true
			}
			return nil
		}
	})
	g.Go(func() error {
		if s.Dummy {
			proofType = s.ProofType
			resp, _ := s.DummyProofProducer.RequestBatchProofs(items, s.ProofType)
			batchProofs = resp.BatchProof
		} else {
			if resp, err := s.requestBatchProof(
				ctx,
				opts,
				metas,
				true,
				proofType,
				requestAt,
				items[0].Opts.IsRethProofAggregationGenerated(),
			); err != nil {
				return err
			} else {
				// Note: we mark the `IsRethProofAggregationGenerated` in the first item with true
				// to record if it is first time generated
				if items[0].Opts.IsShasta() {
					items[0].Opts.ShastaOptions().RethProofAggregationGenerated = true
				} else {
					items[0].Opts.PacayaOptions().RethProofAggregationGenerated = true
				}
				batchProofs = common.Hex2Bytes(resp.Data.Proof.Proof[2:])
			}
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}

	return &BatchProofs{
		ProofResponses:       items,
		BatchProof:           batchProofs,
		BatchIDs:             batchIDs,
		ProofType:            proofType,
		Verifier:             verifier,
		VerifierID:           verifierID,
		SgxGethBatchProof:    sgxGethBatchProofs.BatchProof,
		SgxGethProofVerifier: sgxGethBatchProofs.Verifier,
		SgxGethVerifierID:    sgxGethBatchProofs.VerifierID,
	}, nil
}

// requestBatchProof poll the proof aggregation service to get the aggregated proof.
func (s *ComposeProofProducer) requestBatchProof(
	ctx context.Context,
	opts []ProofRequestOptions,
	metas []metadata.TaikoProposalMetaData,
	isAggregation bool,
	proofType ProofType,
	requestAt time.Time,
	alreadyGenerated bool,
) (*RaikoRequestProofBodyResponseV2, error) {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()
	if len(opts) == 0 || len(opts) != len(metas) {
		return nil, ErrInvalidLength
	}
	var (
		output     *RaikoRequestProofBodyResponseV2
		err        error
		batches    = make([]*RaikoBatches, 0, len(opts))
		proposals  = make([]*RaikoProposals, 0, len(opts))
		start, end *big.Int
	)

	if metas[0].IsShasta() {
		for i, meta := range metas {
			proposals = append(proposals, &RaikoProposals{
				ProposalId:             meta.Shasta().GetEventData().Id,
				L1InclusionBlockNumber: meta.GetRawBlockHeight(),
				L2BlockNumbers:         opts[i].ShastaOptions().L2BlockNums,
				Checkpoint: &RaikoCheckpoint{
					BlockNum:  opts[i].ShastaOptions().Checkpoint.BlockNumber,
					BlockHash: common.BytesToHash(opts[i].ShastaOptions().Checkpoint.BlockHash[:]).Hex()[2:],
					StateRoot: common.BytesToHash(opts[i].ShastaOptions().Checkpoint.StateRoot[:]).Hex()[2:],
				},
				LastAnchorBlockNumber: opts[i].ShastaOptions().LastAnchorBlockNumber,
			})
		}
		output, err = requestHTTPProof[RaikoRequestProofBodyV3Shasta, RaikoRequestProofBodyResponseV2](
			ctx,
			s.RaikoHostEndpoint+"/v3/proof/batch/shasta",
			s.ApiKey,
			RaikoRequestProofBodyV3Shasta{
				Type:      proofType,
				Proposals: proposals,
				Prover:    opts[0].GetProverAddress().Hex()[2:],
				Aggregate: isAggregation,
			},
		)
		start, end = proposals[0].ProposalId, proposals[len(proposals)-1].ProposalId
	} else {
		for _, meta := range metas {
			batches = append(batches, &RaikoBatches{
				BatchID:                meta.Pacaya().GetBatchID(),
				L1InclusionBlockNumber: meta.GetRawBlockHeight(),
			})
		}
		output, err = requestHTTPProof[RaikoRequestProofBodyV3Pacaya, RaikoRequestProofBodyResponseV2](
			ctx,
			s.RaikoHostEndpoint+"/v3/proof/batch",
			s.ApiKey,
			RaikoRequestProofBodyV3Pacaya{
				Type:      proofType,
				Batches:   batches,
				Prover:    opts[0].GetProverAddress().Hex()[2:],
				Aggregate: isAggregation,
			},
		)
		start, end = batches[0].BatchID, batches[len(batches)-1].BatchID
	}
	if err != nil {
		return nil, err
	}

	if err := output.Validate(); err != nil {
		log.Debug(
			"Proof output validation result",
			"start", start,
			"end", end,
			"proofType", output.ProofType,
			"err", err,
		)
		return nil, fmt.Errorf("invalid Raiko response(start: %d, end: %d): %w",
			start,
			end,
			err,
		)
	}

	if !alreadyGenerated {
		proofType = output.ProofType
		log.Info(
			"Batch proof generated",
			"isAggregation", isAggregation,
			"proofType", proofType,
			"start", start,
			"end", end,
			"time", time.Since(requestAt),
		)
		// Update metrics.
		updateProvingMetrics(proofType, requestAt, isAggregation)
	}

	return output, nil
}
