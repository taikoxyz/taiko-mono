package healthchecker

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/bindings/guardianprover"
	hchttp "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/http"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/repo"
	"github.com/urfave/cli/v2"
)

type HealthChecker struct {
	ctx                    context.Context
	cancelCtx              context.CancelFunc
	healthCheckRepo        guardianproverhealthcheck.HealthCheckRepository
	guardianProverContract *guardianprover.GuardianProver
	numGuardians           uint64
	guardianProvers        []guardianproverhealthcheck.GuardianProver
	httpSrv                *hchttp.Server
	httpPort               uint64
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

	signedBlockRepo, err := repo.NewSignedBlockRepository(db)
	if err != nil {
		return err
	}

	startupRepo, err := repo.NewStartupRepository(db)
	if err != nil {
		return err
	}

	l1EthClient, err := ethclient.Dial(cfg.L1RPCUrl)
	if err != nil {
		return err
	}

	l2EthClient, err := ethclient.Dial(cfg.L2RPCUrl)
	if err != nil {
		return err
	}

	guardianProverContract, err := guardianprover.NewGuardianProver(
		common.HexToAddress(cfg.GuardianProverContractAddress),
		l1EthClient,
	)
	if err != nil {
		return err
	}

	numGuardians, err := guardianProverContract.NumGuardians(nil)
	if err != nil {
		return err
	}

	var guardianProvers []guardianproverhealthcheck.GuardianProver

	for i := 0; i < int(numGuardians.Uint64()); i++ {
		guardianAddress, err := guardianProverContract.Guardians(&bind.CallOpts{}, new(big.Int).SetInt64(int64(i)))
		if err != nil {
			return err
		}

		guardianId, err := guardianProverContract.GuardianIds(&bind.CallOpts{}, guardianAddress)
		if err != nil {
			return err
		}

		slog.Info("setting guardian prover address", "address", guardianAddress.Hex(), "id", guardianId.Uint64())

		guardianProvers = append(guardianProvers, guardianproverhealthcheck.GuardianProver{
			Address: guardianAddress,
			ID:      guardianId,
			HealthCheckCounter: promauto.NewCounter(prometheus.CounterOpts{
				Name: fmt.Sprintf("guardian_prover_%v_health_checks_ops_total", guardianId.Uint64()),
				Help: "The total number of health checks",
			}),
			SignedBlockCounter: promauto.NewCounter(prometheus.CounterOpts{
				Name: fmt.Sprintf("guardian_prover_%v_signed_block_ops_total", guardianId.Uint64()),
				Help: "The total number of signed blocks",
			}),
		})
	}

	h.httpSrv, err = hchttp.NewServer(hchttp.NewServerOpts{
		Echo:            echo.New(),
		EthClient:       l2EthClient,
		HealthCheckRepo: healthCheckRepo,
		SignedBlockRepo: signedBlockRepo,
		StartupRepo:     startupRepo,
		GuardianProvers: guardianProvers,
	})

	if err != nil {
		return err
	}

	h.guardianProvers = guardianProvers
	h.numGuardians = numGuardians.Uint64()
	h.healthCheckRepo = healthCheckRepo
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

	return nil
}
