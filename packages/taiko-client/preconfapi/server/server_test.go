package server

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"
	"github.com/phayes/freeport"
	"github.com/stretchr/testify/suite"
)

type PreconfAPIServerTestSuite struct {
	suite.Suite
	s          *PreconfAPIServer
	testServer *httptest.Server
}

func (s *PreconfAPIServerTestSuite) SetupTest() {
	p, err := New(&NewPreconfAPIServerOpts{})
	s.Nil(err)

	p.echo.HideBanner = true
	p.configureMiddleware([]string{"*"})
	p.configureRoutes()
	s.s = p
	s.testServer = httptest.NewServer(p.echo)
}

func (s *PreconfAPIServerTestSuite) TestHealth() {
	resp := s.sendReq("/healthz")
	defer resp.Body.Close()
	s.Equal(http.StatusOK, resp.StatusCode)
}

func (s *PreconfAPIServerTestSuite) TestRoot() {
	resp := s.sendReq("/")
	defer resp.Body.Close()
	s.Equal(http.StatusOK, resp.StatusCode)
}

func (s *PreconfAPIServerTestSuite) TestStartShutdown() {
	port, err := freeport.GetFreePort()
	s.Nil(err)

	url, err := url.Parse(fmt.Sprintf("http://localhost:%v", port))
	s.Nil(err)

	go func() {
		if err := s.s.Start(fmt.Sprintf(":%v", port)); err != nil {
			log.Error("Failed to start prover server", "error", err)
		}
	}()

	// Wait till the server fully started.
	s.Nil(backoff.Retry(func() error {
		res, err := resty.New().R().Get(url.String() + "/healthz")
		if err != nil {
			return err
		}
		if !res.IsSuccess() {
			return fmt.Errorf("invalid response status code: %d", res.StatusCode())
		}

		return nil
	}, backoff.NewExponentialBackOff()))

	s.Nil(s.s.Shutdown(context.Background()))
}

func (s *PreconfAPIServerTestSuite) TearDownTest() {
	s.testServer.Close()
}

func TestPreconfAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfAPIServerTestSuite))
}

func (s *PreconfAPIServerTestSuite) sendReq(path string) *http.Response {
	res, err := http.Get(s.testServer.URL + path)
	s.Nil(err)
	return res
}
