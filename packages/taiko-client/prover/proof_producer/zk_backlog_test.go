package producer

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// Compile-time assertion that the ZK compose producer satisfies the interface.
var _ ZKBacklogController = (*ComposeProofProducer)(nil)

func TestComposeProofProducerStatusClean(t *testing.T) {
	t.Run("data.clean true", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			require.Equal(t, http.MethodGet, r.Method)
			require.Equal(t, "/v3/prover/status", r.URL.Path)
			_, _ = w.Write([]byte(
				`{"status":"ok","data":{"clean":true,"tasks":{"pending":0},"network":{"risc0":{"inflight_orders":0}}}}`,
			))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		clean, err := p.StatusClean(t.Context())
		require.NoError(t, err)
		require.True(t, clean)
	})

	t.Run("data.clean false", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			_, _ = w.Write([]byte(`{"status":"ok","data":{"clean":false}}`))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		clean, err := p.StatusClean(t.Context())
		require.NoError(t, err)
		require.False(t, clean)
	})

	t.Run("non-200 errors", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusNotFound)
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		_, err := p.StatusClean(t.Context())
		require.Error(t, err)
	})

	t.Run("dummy short-circuits to clean", func(t *testing.T) {
		p := &ComposeProofProducer{Dummy: true}
		clean, err := p.StatusClean(t.Context())
		require.NoError(t, err)
		require.True(t, clean)
	})
}

func TestComposeProofProducerClearBacklog(t *testing.T) {
	t.Run("posts to clear endpoint", func(t *testing.T) {
		var called bool
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			called = true
			require.Equal(t, http.MethodPost, r.Method)
			require.Equal(t, "/v3/prover/clear", r.URL.Path)
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		require.NoError(t, p.ClearBacklog(t.Context()))
		require.True(t, called)
	})

	t.Run("non-200 errors", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		require.Error(t, p.ClearBacklog(t.Context()))
	})

	t.Run("dummy short-circuits to nil", func(t *testing.T) {
		p := &ComposeProofProducer{Dummy: true}
		require.NoError(t, p.ClearBacklog(t.Context()))
	})
}
