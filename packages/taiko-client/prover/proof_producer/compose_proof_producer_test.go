package producer

import (
	"context"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
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

func TestRequestRaikoProofV4UsesUnifiedProposalEndpoint(t *testing.T) {
	var requests []map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/v4/proof/proposal", r.URL.Path)

		var body map[string]any
		require.NoError(t, json.NewDecoder(r.Body).Decode(&body))
		requests = append(requests, body)
		_, _ = w.Write([]byte(`{"status":"ok","proof_type":"risc0","proposal_id_start":1,"proposal_id_end":2,"data":{"status":"completed","proof":"0x1234"}}`))
	}))
	defer server.Close()

	_, _, _, err := requestRaikoProofV4(
		context.Background(),
		server.URL,
		"",
		[]ProofRequestOptions{testProposalOpts(10, 11)},
		[]metadata.TaikoProposalMetaData{testProposalMeta(big.NewInt(1), 100)},
		false,
		ProofTypeZKR0,
	)
	require.NoError(t, err)

	_, _, _, err = requestRaikoProofV4(
		context.Background(),
		server.URL,
		"",
		[]ProofRequestOptions{testProposalOpts(10, 11), testProposalOpts(12, 12)},
		[]metadata.TaikoProposalMetaData{
			testProposalMeta(big.NewInt(1), 100),
			testProposalMeta(big.NewInt(2), 101),
		},
		true,
		ProofTypeZKR0,
	)
	require.NoError(t, err)
	require.Len(t, requests, 2)

	require.Equal(t, false, requests[0]["aggregate"])
	require.Len(t, requests[0]["proposals"], 1)
	require.Equal(t, true, requests[1]["aggregate"])
	require.Len(t, requests[1]["proposals"], 2)
	require.NotContains(t, requests[0], "proposal_id_start")
	require.NotContains(t, requests[0], "proposal_id")
}

func testProposalOpts(l2Start uint64, l2End uint64) *ProposalProofRequestOptions {
	return &ProposalProofRequestOptions{
		ProverAddress: common.HexToAddress("0x000000000000000000000000000000000000abcd"),
		L2BlockNums: []*big.Int{
			new(big.Int).SetUint64(l2Start),
			new(big.Int).SetUint64(l2End),
		},
		Checkpoint: &Checkpoint{
			BlockNumber: big.NewInt(9),
			BlockHash:   common.HexToHash("0x1"),
			StateRoot:   common.HexToHash("0x2"),
		},
		LastAnchorBlockNumber: big.NewInt(9),
	}
}

func testProposalMeta(id *big.Int, l1InclusionBlock uint64) metadata.TaikoProposalMetaData {
	return metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:  id,
			Raw: types.Log{BlockNumber: l1InclusionBlock},
		},
		0,
	)
}
