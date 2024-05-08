package server

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"
	"github.com/phayes/freeport"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-client/prover/proof_producer"
)

type ProverServerTestSuite struct {
	suite.Suite
	s          *ProverServer
	testServer *httptest.Server
}

func (s *ProverServerTestSuite) SetupTest() {
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)

	rpcClient, err := rpc.NewClient(context.Background(), &rpc.ClientConfig{
		L1Endpoint:        os.Getenv("L1_NODE_WS_ENDPOINT"),
		L2Endpoint:        os.Getenv("L2_EXECUTION_ENGINE_WS_ENDPOINT"),
		TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN_ADDRESS")),
		L2EngineEndpoint:  os.Getenv("L2_EXECUTION_ENGINE_AUTH_ENDPOINT"),
		JwtSecret:         os.Getenv("JWT_SECRET"),
		Timeout:           5 * time.Second,
	})
	s.Nil(err)

	configs, err := rpcClient.TaikoL1.GetConfig(nil)
	s.Nil(err)

	p, err := New(&NewProverServerOpts{
		ProverPrivateKey:      l1ProverPrivKey,
		MinOptimisticTierFee:  common.Big1,
		MinSgxTierFee:         common.Big1,
		MinSgxAndZkVMTierFee:  common.Big1,
		MinEthBalance:         common.Big1,
		MinTaikoTokenBalance:  common.Big1,
		MaxExpiry:             time.Hour,
		ProofSubmissionCh:     make(chan<- proofProducer.ProofRequestBody, 1024),
		TaikoL1Address:        common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		AssignmentHookAddress: common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		RPC:                   rpcClient,
		ProtocolConfigs:       &configs,
		LivenessBond:          common.Big0,
	})
	s.Nil(err)

	p.echo.HideBanner = true
	p.configureMiddleware()
	p.configureRoutes()
	s.s = p
	s.testServer = httptest.NewServer(p.echo)
}

func (s *ProverServerTestSuite) TestHealth() {
	resp := s.sendReq("/healthz")
	defer resp.Body.Close()
	s.Equal(http.StatusOK, resp.StatusCode)
}

func (s *ProverServerTestSuite) TestRoot() {
	resp := s.sendReq("/")
	defer resp.Body.Close()
	s.Equal(http.StatusOK, resp.StatusCode)
}

func (s *ProverServerTestSuite) TestStartShutdown() {
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

func (s *ProverServerTestSuite) TearDownTest() {
	s.testServer.Close()
}

func TestProverServerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverServerTestSuite))
}

func (s *ProverServerTestSuite) sendReq(path string) *http.Response {
	res, err := http.Get(s.testServer.URL + path)
	s.Nil(err)
	return res
}
