package producer

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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

func TestComposeProducerProverStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodGet, r.Method)
		require.Equal(t, "/v3/prover/status", r.URL.Path)
		require.Equal(t, "test-key", r.Header.Get("X-API-KEY"))

		require.NoError(t, json.NewEncoder(w).Encode(RaikoProverStatusResponse{
			Status: "ok",
			Data: RaikoProverStatusData{
				Clean: true,
				Tasks: RaikoProverTasks{
					Running: 0,
				},
				Network: RaikoProverNetwork{
					SP1: RaikoProverNetworkStatus{
						InflightOrders: 0,
					},
				},
			},
		}))
	}))
	defer server.Close()

	producer := &ComposeProofProducer{
		RaikoHostEndpoint:   server.URL,
		ApiKey:              "test-key",
		RaikoRequestTimeout: time.Second,
	}

	status, err := producer.ProverStatus(t.Context())
	require.NoError(t, err)
	require.True(t, status.Data.Clean)
}

func TestComposeProducerClearProver(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/v3/prover/clear", r.URL.Path)
		require.Equal(t, "test-key", r.Header.Get("X-API-KEY"))
		require.Equal(t, http.NoBody, r.Body)

		require.NoError(t, json.NewEncoder(w).Encode(RaikoProverClearResponse{Status: "ok"}))
	}))
	defer server.Close()

	producer := &ComposeProofProducer{
		RaikoHostEndpoint:   server.URL,
		ApiKey:              "test-key",
		RaikoRequestTimeout: time.Second,
	}

	require.NoError(t, producer.ClearProver(t.Context()))
}
