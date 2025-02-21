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
	"github.com/ethereum/go-ethereum/params"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

const (
	defaultTimeout                = 1 * time.Minute
	pacayaForkHeightDevnet        = 10
	pacayaForkHeightHekla         = 0
	pacayaForkHeklaMainnet        = 0
	pacayaForkHeightPreconfDevnet = 0
)

// OntakeClients contains all smart contract clients for Ontake fork.
type OntakeClients struct {
	TaikoL1                *ontakeBindings.TaikoL1Client
	LibProposing           *ontakeBindings.LibProposing
	TaikoL2                *ontakeBindings.TaikoL2Client
	TaikoToken             *ontakeBindings.TaikoToken
	GuardianProverMajority *ontakeBindings.GuardianProver
	GuardianProverMinority *ontakeBindings.GuardianProver
	ProverSet              *ontakeBindings.ProverSet
	ForkRouter             *ontakeBindings.ForkRouter
	ForkHeight             uint64
}

// PacayaClients contains all smart contract clients for Pacaya fork.
type PacayaClients struct {
	TaikoInbox           *pacayaBindings.TaikoInboxClient
	TaikoWrapper         *pacayaBindings.TaikoWrapperClient
	ForcedInclusionStore *pacayaBindings.ForcedInclusionStore
	TaikoAnchor          *pacayaBindings.TaikoAnchorClient
	TaikoToken           *pacayaBindings.TaikoToken
	ProverSet            *pacayaBindings.ProverSet
	ForkRouter           *pacayaBindings.ForkRouter
	ComposeVerifier      *pacayaBindings.ComposeVerifier
	PreconfWhitelist     *pacayaBindings.PreconfWhitelist
	ForkHeight           uint64
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
	OntakeClients *OntakeClients
	PacayaClients *PacayaClients
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
	TaikoWrapperAddress           common.Address
	TaikoL2Address                common.Address
	TaikoTokenAddress             common.Address
	ForcedInclusionStoreAddress   common.Address
	PreconfWhitelistAddress       common.Address
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
	if err := c.initOntakeClients(cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize Ontake clients: %w", err)
	}
	if err := c.initPacayaClients(cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize Pacaya clients: %w", err)
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()
	// Initialize the fork height numbers.
	if err := c.initForkHeightConfigs(ctxWithTimeout); err != nil {
		return nil, fmt.Errorf("failed to initialize fork height configs: %w", err)
	}

	// Ensure that the genesis block hash of L1 and L2 match.
	if err := c.ensureGenesisMatched(ctxWithTimeout); err != nil {
		return nil, fmt.Errorf("failed to ensure genesis block matched: %w", err)
	}

	return c, nil
}

// initOntakeClients initializes all Ontake smart contract clients.
func (c *Client) initOntakeClients(cfg *ClientConfig) error {
	taikoL1, err := ontakeBindings.NewTaikoL1Client(cfg.TaikoL1Address, c.L1)
	if err != nil {
		return err
	}

	forkManager, err := ontakeBindings.NewForkRouter(cfg.TaikoL1Address, c.L1)
	if err != nil {
		return err
	}

	libProposing, err := ontakeBindings.NewLibProposing(cfg.TaikoL1Address, c.L1)
	if err != nil {
		return err
	}

	taikoL2, err := ontakeBindings.NewTaikoL2Client(cfg.TaikoL2Address, c.L2)
	if err != nil {
		return err
	}

	var (
		taikoToken             *ontakeBindings.TaikoToken
		guardianProverMajority *ontakeBindings.GuardianProver
		guardianProverMinority *ontakeBindings.GuardianProver
		proverSet              *ontakeBindings.ProverSet
	)
	if cfg.TaikoTokenAddress.Hex() != ZeroAddress.Hex() {
		if taikoToken, err = ontakeBindings.NewTaikoToken(cfg.TaikoTokenAddress, c.L1); err != nil {
			return err
		}
	}
	if cfg.GuardianProverMinorityAddress.Hex() != ZeroAddress.Hex() {
		if guardianProverMinority, err = ontakeBindings.NewGuardianProver(
			cfg.GuardianProverMinorityAddress,
			c.L1,
		); err != nil {
			return err
		}
	}
	if cfg.GuardianProverMajorityAddress.Hex() != ZeroAddress.Hex() {
		if guardianProverMajority, err = ontakeBindings.NewGuardianProver(
			cfg.GuardianProverMajorityAddress,
			c.L1,
		); err != nil {
			return err
		}
	}
	if cfg.ProverSetAddress.Hex() != ZeroAddress.Hex() {
		if proverSet, err = ontakeBindings.NewProverSet(cfg.ProverSetAddress, c.L1); err != nil {
			return err
		}
	}

	c.OntakeClients = &OntakeClients{
		TaikoL1:                taikoL1,
		LibProposing:           libProposing,
		TaikoL2:                taikoL2,
		TaikoToken:             taikoToken,
		GuardianProverMajority: guardianProverMajority,
		GuardianProverMinority: guardianProverMinority,
		ProverSet:              proverSet,
		ForkRouter:             forkManager,
	}

	return nil
}

// initPacayaClients initializes all Pacaya smart contract clients.
func (c *Client) initPacayaClients(cfg *ClientConfig) error {
	taikoInbox, err := pacayaBindings.NewTaikoInboxClient(cfg.TaikoL1Address, c.L1)
	if err != nil {
		return err
	}

	forkManager, err := pacayaBindings.NewForkRouter(cfg.TaikoL1Address, c.L1)
	if err != nil {
		return err
	}

	taikoAnchor, err := pacayaBindings.NewTaikoAnchorClient(cfg.TaikoL2Address, c.L2)
	if err != nil {
		return err
	}

	var (
		taikoToken           *pacayaBindings.TaikoToken
		proverSet            *pacayaBindings.ProverSet
		taikoWrapper         *pacayaBindings.TaikoWrapperClient
		forcedInclusionStore *pacayaBindings.ForcedInclusionStore
		preconfWhitelist     *pacayaBindings.PreconfWhitelist
	)
	if cfg.TaikoTokenAddress.Hex() != ZeroAddress.Hex() {
		if taikoToken, err = pacayaBindings.NewTaikoToken(cfg.TaikoTokenAddress, c.L1); err != nil {
			return err
		}
	}
	if cfg.ProverSetAddress.Hex() != ZeroAddress.Hex() {
		if proverSet, err = pacayaBindings.NewProverSet(cfg.ProverSetAddress, c.L1); err != nil {
			return err
		}
	}
	var cancel context.CancelFunc
	opts := &bind.CallOpts{Context: context.Background()}
	opts.Context, cancel = CtxWithTimeoutOrDefault(opts.Context, defaultTimeout)
	defer cancel()
	composeVerifierAddress, err := taikoInbox.Verifier(opts)
	if err != nil {
		return err
	}
	composeVerifier, err := pacayaBindings.NewComposeVerifier(composeVerifierAddress, c.L1)
	if err != nil {
		return err
	}

	if cfg.TaikoWrapperAddress.Hex() != ZeroAddress.Hex() {
		if taikoWrapper, err = pacayaBindings.NewTaikoWrapperClient(cfg.TaikoWrapperAddress, c.L1); err != nil {
			return err
		}
	}

	if cfg.ForcedInclusionStoreAddress.Hex() != ZeroAddress.Hex() {
		if forcedInclusionStore, err = pacayaBindings.NewForcedInclusionStore(
			cfg.ForcedInclusionStoreAddress,
			c.L1,
		); err != nil {
			return err
		}
	}

	if cfg.PreconfWhitelistAddress.Hex() != ZeroAddress.Hex() {
		preconfWhitelist, err = pacayaBindings.NewPreconfWhitelist(cfg.PreconfWhitelistAddress, c.L1)
		if err != nil {
			return err
		}
	}

	c.PacayaClients = &PacayaClients{
		TaikoInbox:           taikoInbox,
		TaikoAnchor:          taikoAnchor,
		TaikoToken:           taikoToken,
		ProverSet:            proverSet,
		ForkRouter:           forkManager,
		TaikoWrapper:         taikoWrapper,
		ForcedInclusionStore: forcedInclusionStore,
		ComposeVerifier:      composeVerifier,
		PreconfWhitelist:     preconfWhitelist,
	}

	return nil
}

// initForkHeightConfigs initializes the fork heights in protocol.
func (c *Client) initForkHeightConfigs(ctx context.Context) error {
	protocolConfigs, err := c.PacayaClients.TaikoInbox.PacayaConfig(&bind.CallOpts{Context: ctx})
	// If failed to get protocol configs, we assuming the current chain is still before the Pacaya fork,
	// use pre-defined Pacaya fork height.
	if err != nil {
		log.Debug(
			"Failed to get protocol configs, using pre-defined Pacaya fork height",
			"error", err,
		)
		switch c.L2.ChainID.Uint64() {
		case params.HeklaNetworkID.Uint64():
			c.PacayaClients.ForkHeight = pacayaForkHeightHekla
		case params.TaikoMainnetNetworkID.Uint64():
			c.PacayaClients.ForkHeight = pacayaForkHeklaMainnet
		case params.PreconfDevnetNetworkID.Uint64():
			c.PacayaClients.ForkHeight = pacayaForkHeightPreconfDevnet
		default:
			log.Debug("Using devnet Pacaya fork height", "height", pacayaForkHeightDevnet)
			c.PacayaClients.ForkHeight = pacayaForkHeightDevnet
		}

		log.Info(
			"Pacaya fork client fork height",
			"chainID", c.L2.ChainID.Uint64(),
			"forkHeight", c.PacayaClients.ForkHeight,
		)

		ontakeProtocolConfigs, err := c.OntakeClients.TaikoL1.GetConfig(&bind.CallOpts{Context: ctx})
		if err != nil {
			return fmt.Errorf("failed to get Ontake protocol configs: %w", err)
		}
		c.OntakeClients.ForkHeight = ontakeProtocolConfigs.OntakeForkHeight
		return nil
	}

	// Otherwise, chain is after the Pacaya fork, just use the fork height numbers from the protocol configs.
	c.OntakeClients.ForkHeight = protocolConfigs.ForkHeights.Ontake
	c.PacayaClients.ForkHeight = protocolConfigs.ForkHeights.Pacaya

	return nil
}
