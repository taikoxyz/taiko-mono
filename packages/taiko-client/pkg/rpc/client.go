package rpc

import (
	"context"
	"fmt"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/prysmaticlabs/prysm/v4/api/client"
	"github.com/prysmaticlabs/prysm/v4/api/client/beacon"

	"github.com/taikoxyz/taiko-client/bindings"
)

const (
	defaultTimeout = 1 * time.Minute
)

// Client contains all L1/L2 RPC clients that a driver needs.
type Client struct {
	// Geth ethclient clients
	L1           *EthClient
	L2           *EthClient
	L2CheckPoint *EthClient
	// Geth Engine API clients
	L2Engine *EngineClient
	// Beacon clients
	L1Beacon *beacon.Client
	// Protocol contracts clients
	TaikoL1        *bindings.TaikoL1Client
	TaikoL2        *bindings.TaikoL2Client
	TaikoToken     *bindings.TaikoToken
	GuardianProver *bindings.GuardianProver
}

// ClientConfig contains all configs which will be used to initializing an
// RPC client. If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
// won't be initialized.
type ClientConfig struct {
	L1Endpoint            string
	L2Endpoint            string
	L1BeaconEndpoint      string
	L2CheckPoint          string
	TaikoL1Address        common.Address
	TaikoL2Address        common.Address
	TaikoTokenAddress     common.Address
	GuardianProverAddress common.Address
	L2EngineEndpoint      string
	JwtSecret             string
	Timeout               time.Duration
}

// NewClient initializes all RPC clients used by Taiko client software.
func NewClient(ctx context.Context, cfg *ClientConfig) (*Client, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	l1Client, err := NewEthClient(ctxWithTimeout, cfg.L1Endpoint, cfg.Timeout)
	if err != nil {
		return nil, err
	}

	l2Client, err := NewEthClient(ctxWithTimeout, cfg.L2Endpoint, cfg.Timeout)
	if err != nil {
		return nil, err
	}

	taikoL1, err := bindings.NewTaikoL1Client(cfg.TaikoL1Address, l1Client)
	if err != nil {
		return nil, err
	}

	taikoL2, err := bindings.NewTaikoL2Client(cfg.TaikoL2Address, l2Client)
	if err != nil {
		return nil, err
	}

	var (
		taikoToken     *bindings.TaikoToken
		guardianProver *bindings.GuardianProver
	)
	if cfg.TaikoTokenAddress.Hex() != ZeroAddress.Hex() {
		if taikoToken, err = bindings.NewTaikoToken(cfg.TaikoTokenAddress, l1Client); err != nil {
			return nil, err
		}
	}
	if cfg.GuardianProverAddress.Hex() != ZeroAddress.Hex() {
		if guardianProver, err = bindings.NewGuardianProver(cfg.GuardianProverAddress, l1Client); err != nil {
			return nil, err
		}
	}

	stateVars, err := taikoL1.GetStateVariables(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}
	isArchive, err := IsArchiveNode(ctxWithTimeout, l1Client, stateVars.A.GenesisHeight)
	if err != nil {
		return nil, err
	}
	if !isArchive {
		return nil, fmt.Errorf("error with RPC endpoint: node (%s) must be archive node", cfg.L1Endpoint)
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

	var l1BeaconClient *beacon.Client
	if cfg.L1BeaconEndpoint != "" {
		if l1BeaconClient, err = beacon.NewClient(cfg.L1BeaconEndpoint, client.WithTimeout(defaultTimeout)); err != nil {
			return nil, err
		}
	}

	var l2CheckPoint *EthClient
	if cfg.L2CheckPoint != "" {
		l2CheckPoint, err = NewEthClient(ctxWithTimeout, cfg.L2CheckPoint, cfg.Timeout)
		if err != nil {
			return nil, err
		}
	}

	client := &Client{
		L1:             l1Client,
		L1Beacon:       l1BeaconClient,
		L2:             l2Client,
		L2CheckPoint:   l2CheckPoint,
		L2Engine:       l2AuthClient,
		TaikoL1:        taikoL1,
		TaikoL2:        taikoL2,
		TaikoToken:     taikoToken,
		GuardianProver: guardianProver,
	}

	if err := client.ensureGenesisMatched(ctxWithTimeout); err != nil {
		return nil, err
	}

	return client, nil
}
