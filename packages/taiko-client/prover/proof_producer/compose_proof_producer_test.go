package producer

import (
	"context"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestComposeProducerRequestProof(t *testing.T) {
	var (
		producer = &ComposeProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
		}
		blockID = common.Big32
		opts    = &ProposalProofRequestOptions{
			ProofType:          ProofTypeZKSP1,
			CompanionProofType: ProofTypeSgxGeth,
		}
	)
	res, err := producer.RequestProof(
		context.Background(),
		opts,
		blockID,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BatchID, blockID)
	require.NotEmpty(t, res.Proof)
	require.True(t, opts.CompanionProofGenerated)
}

func TestComposeProducerAggregateUsesItemProofType(t *testing.T) {
	opts := &ProposalProofRequestOptions{
		ProofType:          ProofTypeZKSP1,
		CompanionProofType: ProofTypeSgxGeth,
	}
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeSgxGeth: 1,
			ProofTypeZKSP1:   6,
		},
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
	}

	result, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeZKSP1,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: opts,
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, result.ProofType)
	require.True(t, opts.CompanionProofAggregationGenerated)
}

func TestComposeProducerAggregateUsesSGXRethVerifierID(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeSgxGeth: 1,
			ProofTypeSgx:     4,
		},
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
	}

	result, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeSgx,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: &ProposalProofRequestOptions{
					ProofType:          ProofTypeSgx,
					CompanionProofType: ProofTypeSgxGeth,
				},
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeSgx, result.ProofType)
	require.Equal(t, uint8(4), result.VerifierID)
	require.Equal(t, uint8(1), result.CompanionVerifierID)
}

func TestComposeProducerAggregateRejectsInconsistentCompanionProofTypes(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeSgxGeth: 1,
			ProofTypeSgx:     4,
			ProofTypeZKSP1:   6,
		},
		Dummy: true,
	}
	items := []*ProofResponse{
		{
			BatchID:   common.Big1,
			ProofType: ProofTypeZKSP1,
			Meta: metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
				0,
			),
			Opts: &ProposalProofRequestOptions{CompanionProofType: ProofTypeSgx},
		},
		{
			BatchID:   common.Big2,
			ProofType: ProofTypeZKSP1,
			Meta: metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{Id: common.Big2},
				0,
			),
			Opts: &ProposalProofRequestOptions{CompanionProofType: ProofTypeSgxGeth},
		},
	}

	_, err := producer.Aggregate(context.Background(), items, time.Now())

	require.ErrorContains(t, err, "inconsistent companion proof type: expected sgx, got sgxgeth")
}

// raikoRequestRecorder records proof requests and returns the configured proof hex string.
type raikoRequestRecorder struct {
	mu                sync.Mutex
	requests          []RaikoRequestProofBodyV4
	proofs            map[ProofType]string
	responseProofType ProofType
}

func (r *raikoRequestRecorder) handler() http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodPost || req.URL.Path != "/v4/proof/proposal" {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		var body RaikoRequestProofBodyV4
		if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		r.mu.Lock()
		r.requests = append(r.requests, body)
		r.mu.Unlock()

		responseProofType := body.ProofType
		if r.responseProofType != "" {
			responseProofType = r.responseProofType
		}
		_ = json.NewEncoder(w).Encode(&RaikoRequestProofBodyResponse{
			ProofType: responseProofType,
			Data:      &RaikoProofData{Proof: r.proofs[body.ProofType]},
		})
	}
}

func (r *raikoRequestRecorder) requestedTypes() map[ProofType]int {
	r.mu.Lock()
	defer r.mu.Unlock()
	types := make(map[ProofType]int, len(r.requests))
	for _, req := range r.requests {
		types[req.ProofType]++
	}
	return types
}

func TestComposeProducerRequestProofRequestsSGXRethAndSgxGethCompanion(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		ProofTypeSgx:     "0xaaaa",
		ProofTypeSgxGeth: "0xbbbb",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{
		ProofType:          ProofTypeSgx,
		CompanionProofType: ProofTypeSgxGeth,
		L2BlockNums:        []*big.Int{common.Big1},
	}

	result, err := producer.RequestProof(
		context.Background(),
		opts,
		common.Big1,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: common.Big1}, 0),
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeSgx, result.ProofType)
	require.Equal(t, common.Hex2Bytes("aaaa"), result.Proof)
	require.Equal(t, map[ProofType]int{ProofTypeSgx: 1, ProofTypeSgxGeth: 1}, recorder.requestedTypes())
}

func TestComposeProducerRequestProofRequestsPrimaryAndSgxGethCompanion(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		ProofTypeZKSP1:   "",
		ProofTypeSgxGeth: "0xbbbb",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{
		ProofType:          ProofTypeZKSP1,
		CompanionProofType: ProofTypeSgxGeth,
		L2BlockNums:        []*big.Int{common.Big1},
	}

	result, err := producer.RequestProof(
		context.Background(),
		opts,
		common.Big1,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: common.Big1}, 0),
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, result.ProofType)
	require.Empty(t, result.Proof)
	require.Equal(t, map[ProofType]int{ProofTypeZKSP1: 1, ProofTypeSgxGeth: 1}, recorder.requestedTypes())
	require.True(t, opts.RethProofGenerated)
	require.True(t, opts.CompanionProofGenerated)
}

func TestComposeProducerAggregateRequestsPrimaryAndSgxGethCompanion(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		ProofTypeZKSP1:   "0xaaaa",
		ProofTypeSgxGeth: "0xbbbb",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeSgxGeth: 1,
			ProofTypeZKSP1:   6,
		},
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{
		ProofType:          ProofTypeZKSP1,
		CompanionProofType: ProofTypeSgxGeth,
		L2BlockNums:        []*big.Int{common.Big1},
	}

	result, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeZKSP1,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: opts,
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, map[ProofType]int{ProofTypeZKSP1: 1, ProofTypeSgxGeth: 1}, recorder.requestedTypes())
	require.Equal(t, uint8(6), result.VerifierID)
	require.Equal(t, common.Hex2Bytes("aaaa"), result.BatchProof)
	require.Equal(t, uint8(1), result.CompanionVerifierID)
	require.Equal(t, common.Hex2Bytes("bbbb"), result.CompanionBatchProof)
	require.True(t, opts.RethProofAggregationGenerated)
	require.True(t, opts.CompanionProofAggregationGenerated)
}

func TestComposeProducerAggregateRequestsPrimaryAndSGXRethCompanion(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		ProofTypeZKSP1: "0xaaaa",
		ProofTypeSgx:   "0xbbbb",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeSgx:   4,
			ProofTypeZKSP1: 6,
		},
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{
		ProofType:          ProofTypeZKSP1,
		CompanionProofType: ProofTypeSgx,
		L2BlockNums:        []*big.Int{common.Big1},
	}

	result, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeZKSP1,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: opts,
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, map[ProofType]int{ProofTypeZKSP1: 1, ProofTypeSgx: 1}, recorder.requestedTypes())
	require.Equal(t, uint8(6), result.VerifierID)
	require.Equal(t, common.Hex2Bytes("aaaa"), result.BatchProof)
	require.Equal(t, uint8(4), result.CompanionVerifierID)
	require.Equal(t, common.Hex2Bytes("bbbb"), result.CompanionBatchProof)
}
