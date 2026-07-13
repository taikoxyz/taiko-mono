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
			SgxGethProducer:    &SgxGethProofProducer{Dummy: true},
		}
		blockID = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProposalProofRequestOptions{},
		blockID,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BatchID, blockID)
	require.NotEmpty(t, res.Proof)
}

func TestComposeProducerAggregateUsesItemProofType(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKSP1: 6,
		},
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
		SgxGethProducer:    &SgxGethProofProducer{Dummy: true},
		ProofType:          ProofTypeZKR0,
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
				Opts: &ProposalProofRequestOptions{},
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, result.ProofType)
}

// TestComposeProducerZkOnlyRequestProofDummy ensures the ZK-only path never touches the
// SGX_GETH leg (a nil SgxGethProducer would panic otherwise) and pins the primary proof
// type to SP1.
func TestComposeProducerZkOnlyRequestProofDummy(t *testing.T) {
	var (
		producer = &ComposeProofProducer{
			ZkOnly:             true,
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			ProofType:          ProofTypeZKR0,
		}
		blockID = common.Big32
		opts    = &ProposalProofRequestOptions{}
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
	require.Equal(t, ProofTypeZKSP1, res.ProofType)
	require.NotEmpty(t, res.Proof)
}

// TestComposeProducerZkOnlyAggregateDummy ensures the ZK-only aggregation pairs the primary
// proof with a RISC0 companion proof instead of an SGX_GETH one.
func TestComposeProducerZkOnlyAggregateDummy(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKR0:  5,
			ProofTypeZKSP1: 6,
		},
		ZkOnly:             true,
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
				Opts: &ProposalProofRequestOptions{},
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, result.ProofType)
	require.Equal(t, uint8(6), result.VerifierID)
	require.Equal(t, uint8(5), result.CompanionVerifierID)
	require.NotEmpty(t, result.BatchProof)
	require.NotEmpty(t, result.CompanionBatchProof)
}

func TestComposeProducerZkOnlyAggregateRequiresRisc0VerifierID(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKSP1: 6,
		},
		ZkOnly:             true,
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
	}

	_, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeZKSP1,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: &ProposalProofRequestOptions{},
			},
		},
		time.Now(),
	)

	require.ErrorContains(t, err, "no verifier ID")
}

// raikoRequestRecorder records the proof requests a test raiko server receives and answers
// each with the given per-proof-type proof hex string.
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

func TestComposeProducerZkOnlyRequestProofRequestsBothZkProofs(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		// A single SP1 proof from raiko is null, only the RISC0 companion carries bytes.
		ProofTypeZKSP1: "",
		ProofTypeZKR0:  "0xff01",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	var (
		producer = &ComposeProofProducer{
			VerifierIDs: map[ProofType]uint8{
				ProofTypeZKR0:  5,
				ProofTypeZKSP1: 6,
			},
			ZkOnly:              true,
			RaikoHostEndpoint:   server.URL,
			RaikoRequestTimeout: time.Second,
			ProofType:           ProofTypeZKR0,
		}
		opts = &ProposalProofRequestOptions{L2BlockNums: []*big.Int{common.Big1}}
	)

	res, err := producer.RequestProof(
		context.Background(),
		opts,
		common.Big1,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: common.Big1}, 0),
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, res.ProofType)
	require.Equal(t, map[ProofType]int{ProofTypeZKSP1: 1, ProofTypeZKR0: 1}, recorder.requestedTypes())
	for _, req := range recorder.requests {
		require.False(t, req.Aggregate)
	}
	require.True(t, opts.RethProofGenerated)
	require.True(t, opts.Risc0CompanionProofGenerated)
	require.False(t, opts.GethProofGenerated)
}

func TestComposeProducerZkOnlyAggregateRequestsBothZkAggregations(t *testing.T) {
	recorder := &raikoRequestRecorder{proofs: map[ProofType]string{
		ProofTypeZKSP1: "0xaaaa",
		ProofTypeZKR0:  "0xbbbb",
	}}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	var (
		producer = &ComposeProofProducer{
			VerifierIDs: map[ProofType]uint8{
				ProofTypeZKR0:  5,
				ProofTypeZKSP1: 6,
			},
			ZkOnly:              true,
			RaikoHostEndpoint:   server.URL,
			RaikoRequestTimeout: time.Second,
		}
		opts = &ProposalProofRequestOptions{L2BlockNums: []*big.Int{common.Big1}}
	)

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
	require.Equal(t, map[ProofType]int{ProofTypeZKSP1: 1, ProofTypeZKR0: 1}, recorder.requestedTypes())
	for _, req := range recorder.requests {
		require.True(t, req.Aggregate)
	}
	require.Equal(t, uint8(6), result.VerifierID)
	require.Equal(t, common.Hex2Bytes("aaaa"), result.BatchProof)
	require.Equal(t, uint8(5), result.CompanionVerifierID)
	require.Equal(t, common.Hex2Bytes("bbbb"), result.CompanionBatchProof)
	require.True(t, opts.RethProofAggregationGenerated)
	require.True(t, opts.Risc0CompanionProofAggregationGenerated)
	require.False(t, opts.GethProofAggregationGenerated)
}

func TestComposeProducerZkOnlyRequestProofRejectsMismatchedCompanionType(t *testing.T) {
	recorder := &raikoRequestRecorder{
		proofs: map[ProofType]string{
			ProofTypeZKSP1: "",
			ProofTypeZKR0:  "0xff01",
		},
		responseProofType: ProofTypeZKSP1,
	}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKR0:  5,
			ProofTypeZKSP1: 6,
		},
		ZkOnly:              true,
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{L2BlockNums: []*big.Int{common.Big1}}

	_, err := producer.RequestProof(
		context.Background(),
		opts,
		common.Big1,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: common.Big1}, 0),
		time.Now(),
	)

	require.ErrorContains(t, err, "requested risc0, got sp1")
	require.False(t, opts.Risc0CompanionProofGenerated)
}

func TestComposeProducerZkOnlyAggregateRejectsMismatchedCompanionType(t *testing.T) {
	recorder := &raikoRequestRecorder{
		proofs: map[ProofType]string{
			ProofTypeZKSP1: "0xaaaa",
			ProofTypeZKR0:  "0xbbbb",
		},
		responseProofType: ProofTypeZKSP1,
	}
	server := httptest.NewServer(recorder.handler())
	defer server.Close()

	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKR0:  5,
			ProofTypeZKSP1: 6,
		},
		ZkOnly:              true,
		RaikoHostEndpoint:   server.URL,
		RaikoRequestTimeout: time.Second,
	}
	opts := &ProposalProofRequestOptions{L2BlockNums: []*big.Int{common.Big1}}

	_, err := producer.Aggregate(
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

	require.ErrorContains(t, err, "requested risc0, got sp1")
	require.False(t, opts.Risc0CompanionProofAggregationGenerated)
}
