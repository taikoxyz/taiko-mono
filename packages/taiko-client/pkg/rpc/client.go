package rpc

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	legacyBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	DefaultRpcTimeout = 1 * time.Minute
)

// L1Contracts contains shared L1 helper contracts still used by taiko-client.
type L1Contracts struct {
	TaikoWrapper         *legacyBindings.TaikoWrapperClient
	ForcedInclusionStore *legacyBindings.ForcedInclusionStore
	PreconfWhitelist     *legacyBindings.PreconfWhitelist
	PreconfRouter        *legacyBindings.PreconfRouter
}

// ShastaClients contains all smart contract clients for ShastaClients fork.
type ShastaClients struct {
	Inbox           *shastaBindings.ShastaInboxClient
	Anchor          *shastaBindings.ShastaAnchor
	ComposeVerifier *shastaBindings.ComposeVerifier
	InboxAddress    common.Address
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
	L1Contracts   *L1Contracts
	ShastaClients *ShastaClients
}

// ClientConfig contains all configs which will be used to initializing an
// RPC client. If not providing L2EngineEndpoint or JwtSecret, then the L2Engine client
// won't be initialized.
type ClientConfig struct {
	L1Endpoint                  string
	L2Endpoint                  string
	L1BeaconEndpoint            string
	L2CheckPoint                string
	InboxAddress                common.Address
	TaikoWrapperAddress         common.Address
	TaikoAnchorAddress          common.Address
	ForcedInclusionStoreAddress common.Address
	PreconfWhitelistAddress     common.Address
	L2EngineEndpoint            string
	JwtSecret                   string
	Timeout                     time.Duration
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
	}

	c := &Client{
		L1:           l1Client,
		L1Beacon:     l1BeaconClient,
		L2:           l2Client,
		L2CheckPoint: l2CheckPoint,
		L2Engine:     l2AuthClient,
	}

	// Initialize all smart contract clients.
	if err := c.initL1Contracts(cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize shared L1 clients: %w", err)
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()
	if err := c.initShastaClients(ctxWithTimeout, cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize Shasta clients: %w", err)
	}

	return c, nil
}

// initL1Contracts initializes the shared L1 helper contracts.
func (c *Client) initL1Contracts(cfg *ClientConfig) error {
	var (
		taikoWrapper         *legacyBindings.TaikoWrapperClient
		forcedInclusionStore *legacyBindings.ForcedInclusionStore
		preconfWhitelist     *legacyBindings.PreconfWhitelist
		preconfRouter        *legacyBindings.PreconfRouter
		err                  error
	)
	if cfg.TaikoWrapperAddress.Hex() != ZeroAddress.Hex() {
		if taikoWrapper, err = legacyBindings.NewTaikoWrapperClient(cfg.TaikoWrapperAddress, c.L1); err != nil {
			return fmt.Errorf("failed to create new instance of TaikoWrapperClient: %w", err)
		}
	}

	if cfg.ForcedInclusionStoreAddress.Hex() != ZeroAddress.Hex() {
		if forcedInclusionStore, err = legacyBindings.NewForcedInclusionStore(
			cfg.ForcedInclusionStoreAddress,
			c.L1,
		); err != nil {
			return fmt.Errorf("failed to create new instance of ForcedInclusionStore: %w", err)
		}
	}

	if cfg.PreconfWhitelistAddress.Hex() != ZeroAddress.Hex() {
		preconfWhitelist, err = legacyBindings.NewPreconfWhitelist(cfg.PreconfWhitelistAddress, c.L1)
		if err != nil {
			return fmt.Errorf("failed to create new instance of PreconfWhitelist: %w", err)
		}
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(context.Background(), DefaultRpcTimeout)
	defer cancel()
	if taikoWrapper != nil {
		preconfRouterAddress, err := taikoWrapper.PreconfRouter(&bind.CallOpts{Context: ctxWithTimeout})
		if err != nil {
			return fmt.Errorf("failed to get address of PreconfRouter: %w", err)
		}
		if preconfRouterAddress.Hex() != ZeroAddress.Hex() {
			preconfRouter, err = legacyBindings.NewPreconfRouter(preconfRouterAddress, c.L1)
			if err != nil {
				return fmt.Errorf("failed to create new instance of PreconfRouter: %w", err)
			}
		}
	}

	c.L1Contracts = &L1Contracts{
		TaikoWrapper:         taikoWrapper,
		ForcedInclusionStore: forcedInclusionStore,
		PreconfWhitelist:     preconfWhitelist,
		PreconfRouter:        preconfRouter,
	}

	return nil
}

// initShastaClients initializes all Shasta smart contract clients.
func (c *Client) initShastaClients(ctx context.Context, cfg *ClientConfig) error {
	inbox, err := shastaBindings.NewShastaInboxClient(cfg.InboxAddress, c.L1)
	if err != nil {
		return fmt.Errorf("failed to create new inbox client: %w", err)
	}

	shastaAnchor, err := shastaBindings.NewShastaAnchor(cfg.TaikoAnchorAddress, c.L2)
	if err != nil {
		return fmt.Errorf("failed to create new instance of ShastaAnchorClient: %w", err)
	}

	config, err := inbox.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get inbox config: %w", err)
	}
	composeVerifier, err := shastaBindings.NewComposeVerifier(config.ProofVerifier, c.L1)
	if err != nil {
		return fmt.Errorf("failed to create new instance of ComposeVerifier: %w", err)
	}
	c.ShastaClients = &ShastaClients{
		Inbox:           inbox,
		Anchor:          shastaAnchor,
		ComposeVerifier: composeVerifier,
		InboxAddress:    cfg.InboxAddress,
	}

	return nil
}
