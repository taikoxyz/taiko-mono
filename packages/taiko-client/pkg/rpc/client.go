package rpc

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	DefaultRpcTimeout = 1 * time.Minute
)

// ShastaClients contains all smart contract clients for ShastaClients fork.
type ShastaClients struct {
	Inbox            *shastaBindings.ShastaInboxClient
	Anchor           *shastaBindings.ShastaAnchor
	ComposeVerifier  *shastaBindings.ComposeVerifier
	PreconfWhitelist *shastaBindings.PreconfWhitelist
	InboxAddress     common.Address
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
	// Protocol contract clients
	ShastaClients *ShastaClients
}

// ClientConfig contains all configs which will be used to initializing an
// RPC client. If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
// won't be initialized.
type ClientConfig struct {
	L1Endpoint         string
	L2Endpoint         string
	L1BeaconEndpoint   string
	L2CheckPoint       string
	InboxAddress       common.Address
	TaikoAnchorAddress common.Address
	L2EngineEndpoint   string
	JwtSecret          string
	Timeout            time.Duration
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
		ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
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
			if l1BeaconClient, err = NewBeaconClient(cfg.L1BeaconEndpoint, DefaultRpcTimeout); err != nil {
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

	// If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
	// won't be initialized.
	var l2AuthClient *EngineClient
	if len(cfg.L2EngineEndpoint) != 0 && len(cfg.JwtSecret) != 0 {
		l2AuthClient, err = NewJWTEngineClient(cfg.L2EngineEndpoint, cfg.JwtSecret)
		if err != nil {
			return nil, err
		}
		l2AuthClient.chainID = new(big.Int).Set(l2Client.ChainID)
	}

	c := &Client{
		L1:           l1Client,
		L1Beacon:     l1BeaconClient,
		L2:           l2Client,
		L2CheckPoint: l2CheckPoint,
		L2Engine:     l2AuthClient,
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()
	if err := c.initShastaClients(ctxWithTimeout, cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize clients: %w", err)
	}

	return c, nil
}

// initShastaClients initializes all smart contract clients.
func (c *Client) initShastaClients(ctx context.Context, cfg *ClientConfig) error {
	inbox, err := shastaBindings.NewShastaInboxClient(cfg.InboxAddress, c.L1)
	if err != nil {
		return fmt.Errorf("failed to create new inbox client: %w", err)
	}

	anchor, err := shastaBindings.NewShastaAnchor(cfg.TaikoAnchorAddress, c.L2)
	if err != nil {
		return fmt.Errorf("failed to create new instance of AnchorClient: %w", err)
	}

	config, err := inbox.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get inbox config: %w", err)
	}
	composeVerifier, err := shastaBindings.NewComposeVerifier(config.ProofVerifier, c.L1)
	if err != nil {
		return fmt.Errorf("failed to create new instance of ComposeVerifier: %w", err)
	}

	var preconfWhitelist *shastaBindings.PreconfWhitelist
	if config.ProposerChecker.Hex() != ZeroAddress.Hex() {
		preconfWhitelist, err = shastaBindings.NewPreconfWhitelist(config.ProposerChecker, c.L1)
		if err != nil {
			return fmt.Errorf("failed to create new instance of PreconfWhitelist: %w", err)
		}
	}

	c.ShastaClients = &ShastaClients{
		Inbox:            inbox,
		Anchor:           anchor,
		ComposeVerifier:  composeVerifier,
		PreconfWhitelist: preconfWhitelist,
		InboxAddress:     cfg.InboxAddress,
	}

	return nil
}
