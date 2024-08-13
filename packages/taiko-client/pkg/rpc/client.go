package rpc

import (
	"context"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	v1 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v1"

	v2 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v2"
)

const (
	defaultTimeout = 1 * time.Minute
)

type V1 struct {
	TaikoL1      *v1.TaikoL1Client
	LibProposing *v1.LibProposing
	TaikoL2      *v1.TaikoL2Client
}

type V2 struct {
	TaikoL1      *v2.TaikoL1Client
	LibProposing *v2.LibProposing
	TaikoL2      *v2.TaikoL2Client
}

// Client contains all L1/L2 RPC clients that a driver needs.
type Client struct {
	// Geth ethclient clients
	L1           *EthClient
	L2           *EthClient
	L2CheckPoint *EthClient
	// Geth Engine API clients
	L2Engine *EngineClient
	// Beacon clients
	L1Beacon *BeaconClient
	// Protocol contracts clients
	V1                     *V1
	V2                     *V2
	TaikoToken             *v2.TaikoToken
	GuardianProverMajority *v2.GuardianProver
	GuardianProverMinority *v2.GuardianProver
	ProverSet              *v2.ProverSet
}

// ClientConfig contains all configs which will be used to initializing an
// RPC client. If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
// won't be initialized.
type ClientConfig struct {
	L1Endpoint                    string
	L2Endpoint                    string
	L1BeaconEndpoint              string
	L2CheckPoint                  string
	TaikoL1Address                common.Address
	TaikoL2Address                common.Address
	TaikoTokenAddress             common.Address
	GuardianProverMinorityAddress common.Address
	GuardianProverMajorityAddress common.Address
	ProverSetAddress              common.Address
	L2EngineEndpoint              string
	JwtSecret                     string
	Timeout                       time.Duration
}

// NewClient initializes all RPC clients used by Taiko client software.
func NewClient(ctx context.Context, cfg *ClientConfig) (*Client, error) {
	var (
		l1Client       *EthClient
		l2Client       *EthClient
		l1BeaconClient *BeaconClient
		l2CheckPoint   *EthClient
		err            error
	)

	// Keep retrying to connect to the RPC endpoints until success or context is cancelled.
	if err := backoff.Retry(func() error {
		ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
		defer cancel()

		if l1Client, err = NewEthClient(ctxWithTimeout, cfg.L1Endpoint, cfg.Timeout); err != nil {
			log.Error("Failed to connect to L1 endpoint, retrying", "endpoint", cfg.L1Endpoint, "err", err)
			return err
		}

		if l2Client, err = NewEthClient(ctxWithTimeout, cfg.L2Endpoint, cfg.Timeout); err != nil {
			log.Error("Failed to connect to L2 endpoint, retrying", "endpoint", cfg.L2Endpoint, "err", err)
			return err
		}

		// NOTE: when running tests, we do not have a L1 beacon endpoint.
		if cfg.L1BeaconEndpoint != "" && os.Getenv("RUN_TESTS") == "" {
			if l1BeaconClient, err = NewBeaconClient(cfg.L1BeaconEndpoint, defaultTimeout); err != nil {
				log.Error("Failed to connect to L1 beacon endpoint, retrying", "endpoint", cfg.L1BeaconEndpoint, "err", err)
				return err
			}
		}

		if cfg.L2CheckPoint != "" {
			l2CheckPoint, err = NewEthClient(ctxWithTimeout, cfg.L2CheckPoint, cfg.Timeout)
			if err != nil {
				log.Error("Failed to connect to L2 checkpoint endpoint, retrying", "endpoint", cfg.L2CheckPoint, "err", err)
				return err
			}
		}

		return nil
	}, backoff.WithContext(backoff.NewExponentialBackOff(), ctx)); err != nil {
		return nil, err
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	taikoL1V1, err := v1.NewTaikoL1Client(cfg.TaikoL1Address, l1Client)
	if err != nil {
		return nil, err
	}

	taikoL1V2, err := v2.NewTaikoL1Client(cfg.TaikoL1Address, l1Client)
	if err != nil {
		return nil, err
	}

	libProposingV1, err := v1.NewLibProposing(cfg.TaikoL1Address, l1Client)
	if err != nil {
		return nil, err
	}

	libProposingV2, err := v2.NewLibProposing(cfg.TaikoL1Address, l1Client)
	if err != nil {
		return nil, err
	}

	taikoL2V1, err := v1.NewTaikoL2Client(cfg.TaikoL2Address, l2Client)
	if err != nil {
		return nil, err
	}

	taikoL2V2, err := v2.NewTaikoL2Client(cfg.TaikoL2Address, l2Client)
	if err != nil {
		return nil, err
	}

	var (
		taikoToken             *v2.TaikoToken
		guardianProverMajority *v2.GuardianProver
		guardianProverMinority *v2.GuardianProver
		proverSet              *v2.ProverSet
	)
	if cfg.TaikoTokenAddress.Hex() != ZeroAddress.Hex() {
		if taikoToken, err = v2.NewTaikoToken(cfg.TaikoTokenAddress, l1Client); err != nil {
			return nil, err
		}
	}
	if cfg.GuardianProverMinorityAddress.Hex() != ZeroAddress.Hex() {
		if guardianProverMinority, err = v2.NewGuardianProver(cfg.GuardianProverMinorityAddress, l1Client); err != nil {
			return nil, err
		}
	}
	if cfg.GuardianProverMajorityAddress.Hex() != ZeroAddress.Hex() {
		if guardianProverMajority, err = v2.NewGuardianProver(cfg.GuardianProverMajorityAddress, l1Client); err != nil {
			return nil, err
		}
	}
	if cfg.ProverSetAddress.Hex() != ZeroAddress.Hex() {
		if proverSet, err = v2.NewProverSet(cfg.ProverSetAddress, l1Client); err != nil {
			return nil, err
		}
	}

	// If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
	// won't be initialized.
	var l2AuthClient *EngineClient
	if len(cfg.L2EngineEndpoint) != 0 && len(cfg.JwtSecret) != 0 {
		l2AuthClient, err = NewJWTEngineClient(cfg.L2EngineEndpoint, cfg.JwtSecret)
		if err != nil {
			return nil, err
		}
	}

	client := &Client{
		L1:           l1Client,
		L1Beacon:     l1BeaconClient,
		L2:           l2Client,
		L2CheckPoint: l2CheckPoint,
		L2Engine:     l2AuthClient,
		V1: &V1{
			TaikoL1:      taikoL1V1,
			TaikoL2:      taikoL2V1,
			LibProposing: libProposingV1,
		},
		V2: &V2{
			TaikoL1:      taikoL1V2,
			TaikoL2:      taikoL2V2,
			LibProposing: libProposingV2,
		},
		TaikoToken:             taikoToken,
		GuardianProverMajority: guardianProverMajority,
		GuardianProverMinority: guardianProverMinority,
		ProverSet:              proverSet,
	}

	if err := client.ensureGenesisMatched(ctxWithTimeout); err != nil {
		return nil, err
	}

	return client, nil
}
