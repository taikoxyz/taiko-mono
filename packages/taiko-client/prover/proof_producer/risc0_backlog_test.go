package producer

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/suite"
)

// Compile-time assertion that the compose producer satisfies the RISC0 backlog controller interface.
var _ Risc0BacklogController = (*ComposeProofProducer)(nil)

type Risc0BacklogTestSuite struct {
	suite.Suite
}

func TestRisc0BacklogTestSuite(t *testing.T) {
	suite.Run(t, new(Risc0BacklogTestSuite))
}

func (s *Risc0BacklogTestSuite) TestStatusCleanReturnsTrue() {
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
}

func (s *Risc0BacklogTestSuite) TestStatusCleanReturnsFalse() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"ok","data":{"clean":false}}`))
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	clean, err := p.StatusClean(s.T().Context())
	s.NoError(err)
	s.False(clean)
}

func (s *Risc0BacklogTestSuite) TestStatusCleanErrorsOnNon200() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	_, err := p.StatusClean(s.T().Context())
	s.Error(err)
}

func (s *Risc0BacklogTestSuite) TestStatusCleanDummyShortCircuits() {
	p := &ComposeProofProducer{Dummy: true}
	clean, err := p.StatusClean(s.T().Context())
	s.NoError(err)
	s.True(clean)
}

func (s *Risc0BacklogTestSuite) TestClearBacklogPostsToEndpoint() {
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

func (s *Risc0BacklogTestSuite) TestClearBacklogErrorsOnNon200() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	p := &ComposeProofProducer{RaikoHostEndpoint: server.URL, RaikoRequestTimeout: time.Second}
	s.Error(p.ClearBacklog(s.T().Context()))
}

func (s *Risc0BacklogTestSuite) TestClearBacklogDummyShortCircuits() {
	p := &ComposeProofProducer{Dummy: true}
	s.NoError(p.ClearBacklog(s.T().Context()))
}
