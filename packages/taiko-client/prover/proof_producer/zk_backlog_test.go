package producer

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/suite"
)

// Compile-time assertion that the ZK compose producer satisfies the interface.
var _ ZKBacklogController = (*ComposeProofProducer)(nil)

type ZKBacklogTestSuite struct {
	suite.Suite
}

func TestZKBacklogTestSuite(t *testing.T) {
	suite.Run(t, new(ZKBacklogTestSuite))
}

func (s *ZKBacklogTestSuite) TestStatusClean() {
	s.Run("data.clean true", func() {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			s.Equal(http.MethodGet, r.Method)
			s.Equal("/v3/prover/status", r.URL.Path)
			_, _ = w.Write([]byte(
				`{"status":"ok","data":{"clean":true,"tasks":{"pending":0},"network":{"risc0":{"inflight_orders":0}}}}`,
			))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		clean, err := p.StatusClean(s.T().Context())
		s.NoError(err)
		s.True(clean)
	})

	s.Run("data.clean false", func() {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte(`{"status":"ok","data":{"clean":false}}`))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		clean, err := p.StatusClean(s.T().Context())
		s.NoError(err)
		s.False(clean)
	})

	s.Run("non-200 errors", func() {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusNotFound)
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		_, err := p.StatusClean(s.T().Context())
		s.Error(err)
	})

	s.Run("dummy short-circuits to clean", func() {
		p := &ComposeProofProducer{Dummy: true}
		clean, err := p.StatusClean(s.T().Context())
		s.NoError(err)
		s.True(clean)
	})
}

func (s *ZKBacklogTestSuite) TestClearBacklog() {
	s.Run("posts to clear endpoint", func() {
		var called bool
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			called = true
			s.Equal(http.MethodPost, r.Method)
			s.Equal("/v3/prover/clear", r.URL.Path)
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		s.NoError(p.ClearBacklog(s.T().Context()))
		s.True(called)
	})

	s.Run("non-200 errors", func() {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
		}))
		defer server.Close()

		p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
		s.Error(p.ClearBacklog(s.T().Context()))
	})

	s.Run("dummy short-circuits to nil", func() {
		p := &ComposeProofProducer{Dummy: true}
		s.NoError(p.ClearBacklog(s.T().Context()))
	})
}
