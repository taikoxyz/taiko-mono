package healthchecker

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math/big"
	"net/http"
	"net/url"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/bindings/guardianprover"
	hchttp "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/http"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/repo"
	"github.com/urfave/cli/v2"
)

var (
	msg = crypto.Keccak256Hash([]byte("HEART_BEAT")).Bytes()
)

type guardianProver struct {
	address  common.Address
	id       *big.Int
	endpoint *url.URL
}

type HealthChecker struct {
	ctx                    context.Context
	cancelCtx              context.CancelFunc
	healthCheckRepo        guardianproverhealthcheck.HealthCheckRepository
	interval               time.Duration
	guardianProverContract *guardianprover.GuardianProver
	numGuardians           uint64
	guardianProvers        []guardianProver
	httpSrv                *hchttp.Server
	httpPort               uint64
}

type healthCheckResponse struct {
	ProverAddress      string `json:"prover"`
	HeartBeatSignature string `json:"heartBeatSignature"`
}

func (h *HealthChecker) Name() string {
	return "healthchecker"
}

func (h *HealthChecker) Close(ctx context.Context) {
	h.cancelCtx()

	if err := h.httpSrv.Shutdown(ctx); err != nil {
		slog.Error("error encountered shutting down http server", "error", err)
	}
}

func (h *HealthChecker) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, h, cfg)
}

func InitFromConfig(ctx context.Context, h *HealthChecker, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	healthCheckRepo, err := repo.NewHealthCheckRepository(db)
	if err != nil {
		return err
	}

	endpoints := make([]*url.URL, 0)

	for _, v := range cfg.GuardianProverEndpoints {
		url, err := url.Parse(v)
		if err != nil {
			return err
		}

		endpoints = append(endpoints, url)
	}

	ethClient, err := ethclient.Dial(cfg.RPCUrl)
	if err != nil {
		return err
	}

	guardianProverContract, err := guardianprover.NewGuardianProver(
		common.HexToAddress(cfg.GuardianProverContractAddress),
		ethClient,
	)
	if err != nil {
		return err
	}

	numGuardians, err := guardianProverContract.NUMGUARDIANS(nil)
	if err != nil {
		return err
	}

	var guardianProvers []guardianProver

	for i := 0; i < int(numGuardians.Uint64()); i++ {
		guardianAddress, err := guardianProverContract.Guardians(&bind.CallOpts{}, new(big.Int).SetInt64(int64(i)))
		if err != nil {
			return err
		}

		guardianId, err := guardianProverContract.GuardianIds(&bind.CallOpts{}, guardianAddress)
		if err != nil {
			return err
		}

		endpoint, err := url.Parse(cfg.GuardianProverEndpoints[i])
		if err != nil {
			return err
		}

		guardianProvers = append(guardianProvers, guardianProver{
			address:  guardianAddress,
			id:       guardianId,
			endpoint: endpoint,
		})
	}

	h.httpSrv, err = hchttp.NewServer(hchttp.NewServerOpts{
		Echo:            echo.New(),
		HealthCheckRepo: healthCheckRepo,
	})

	if err != nil {
		return err
	}

	h.guardianProvers = guardianProvers
	h.numGuardians = numGuardians.Uint64()
	h.healthCheckRepo = healthCheckRepo
	h.interval = cfg.Interval
	h.guardianProverContract = guardianProverContract
	h.httpPort = cfg.HTTPPort

	h.ctx, h.cancelCtx = context.WithCancel(ctx)

	return nil
}

func (h *HealthChecker) Start() error {
	go func() {
		if err := h.httpSrv.Start(fmt.Sprintf(":%v", h.httpPort)); !errors.Is(err, http.ErrServerClosed) {
			slog.Error("Failed to start http server", "error", err)
		}
	}()

	go h.checkGuardianProversOnInterval()

	return nil
}

func (h *HealthChecker) checkGuardianProversOnInterval() {
	t := time.NewTicker(h.interval)

	for {
		select {
		case <-h.ctx.Done():
			return
		case <-t.C:
			for _, g := range h.guardianProvers {
				resp, recoveredAddr, err := h.checkGuardianProver(g)
				if err != nil {
					slog.Error(
						"error checking guardian prover endpoint",
						"endpoint", g.endpoint,
						"id", g.id,
						"address", g.address.Hex(),
						"recoveredAddr", recoveredAddr,
						"error", err,
					)
				}

				var sig string = ""

				if resp != nil {
					sig = resp.HeartBeatSignature
				}

				err = h.healthCheckRepo.Save(
					guardianproverhealthcheck.SaveHealthCheckOpts{
						GuardianProverID: g.id.Uint64(),
						Alive:            sig != "",
						ExpectedAddress:  g.address.Hex(),
						RecoveredAddress: recoveredAddr,
						SignedResponse:   sig,
					},
				)

				if err != nil {
					slog.Error("error saving failed health check to database",
						"endpoint", g.endpoint,
						"id", g.id,
						"address", g.address.Hex(),
						"recoveredAddr", recoveredAddr,
						"sig", sig,
						"error", err,
					)
				} else {
					slog.Info("saved health check to database",
						"endpoint", g.endpoint,
						"id", g.id,
						"address", g.address.Hex(),
						"recoveredAddr", recoveredAddr,
						"sig", sig,
					)
				}
			}
		}
	}
}

func (h *HealthChecker) checkGuardianProver(g guardianProver) (*healthCheckResponse, string, error) {
	slog.Info("checking guardian prover", "id", g.id, "endpoint", g.endpoint)

	healthCheckResponse := &healthCheckResponse{}

	resp, err := http.Get(g.endpoint.String() + "/status")
	if err != nil {
		// save fail to db
		return healthCheckResponse, "", err
	}

	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return healthCheckResponse, "", err
	}

	if err := json.Unmarshal(b, healthCheckResponse); err != nil {
		return healthCheckResponse, "", err
	}

	if g.address.Cmp(common.HexToAddress(healthCheckResponse.ProverAddress)) != 0 {
		slog.Error("address mismatch", "expected", g.address.Hex(), "received", healthCheckResponse.ProverAddress)
		return healthCheckResponse, "", errors.New("prover address provided was not the address expected")
	}

	b64DecodedSig, err := base64.StdEncoding.DecodeString(healthCheckResponse.HeartBeatSignature)
	if err != nil {
		return healthCheckResponse, "", err
	}

	pubKey, err := crypto.SigToPub(msg, b64DecodedSig)
	if err != nil {
		return healthCheckResponse, "", err
	}

	recoveredAddr := crypto.PubkeyToAddress(*pubKey)

	return healthCheckResponse, recoveredAddr.Hex(), nil
}
