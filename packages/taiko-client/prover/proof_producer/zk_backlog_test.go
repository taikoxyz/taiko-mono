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

func (s *ZKBacklogTestSuite) TestRisc0IdleReturnsTrueWhenZero() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s.Equal(http.MethodGet, r.Method)
		s.Equal("/v3/prover/status", r.URL.Path)
		_, _ = w.Write([]byte(
			`{"status":"ok","data":{"network":{"risc0":{"inflight_orders":0}}}}`,
		))
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	idle, err := p.Risc0Idle(s.T().Context())
	s.NoError(err)
	s.True(idle)
}

func (s *ZKBacklogTestSuite) TestRisc0IdleReturnsFalseWhenInflight() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"ok","data":{"network":{"risc0":{"inflight_orders":3}}}}`))
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	idle, err := p.Risc0Idle(s.T().Context())
	s.NoError(err)
	s.False(idle)
}

func (s *ZKBacklogTestSuite) TestRisc0IdleErrorsOnNon200() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	_, err := p.Risc0Idle(s.T().Context())
	s.Error(err)
}

func (s *ZKBacklogTestSuite) TestRisc0IdleErrorsWhenRisc0Missing() {
	// 200 with an older schema lacking network.risc0: treated as unavailable, not
	// silently idle (a busy `clean:false` must not be read as idle).
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"ok","data":{"clean":false}}`))
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	_, err := p.Risc0Idle(s.T().Context())
	s.Error(err)
}

func (s *ZKBacklogTestSuite) TestRisc0IdleErrorsWhenInflightMissing() {
	// risc0 present but without inflight_orders: also unavailable, not idle.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"ok","data":{"network":{"risc0":{}}}}`))
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	_, err := p.Risc0Idle(s.T().Context())
	s.Error(err)
}

func (s *ZKBacklogTestSuite) TestRisc0IdleDummyShortCircuits() {
	p := &ComposeProofProducer{Dummy: true}
	idle, err := p.Risc0Idle(s.T().Context())
	s.NoError(err)
	s.True(idle)
}

func (s *ZKBacklogTestSuite) TestClearBacklogPostsToEndpoint() {
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
}

func (s *ZKBacklogTestSuite) TestClearBacklogErrorsOnNon200() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	s.Error(p.ClearBacklog(s.T().Context()))
}

func (s *ZKBacklogTestSuite) TestClearBacklogDummyShortCircuits() {
	p := &ComposeProofProducer{Dummy: true}
	s.NoError(p.ClearBacklog(s.T().Context()))
}
