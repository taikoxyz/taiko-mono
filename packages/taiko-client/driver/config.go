package driver

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"time"

	p2pFlags "github.com/ethereum-optimism/optimism/op-node/flags"
	"github.com/ethereum-optimism/optimism/op-node/p2p"
	p2pCli "github.com/ethereum-optimism/optimism/op-node/p2p/cli"
	"github.com/ethereum-optimism/optimism/op-node/rollup"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Config contains the configurations to initialize a Taiko driver.
type Config struct {
	*rpc.ClientConfig
	P2PSync                       bool
	P2PSyncTimeout                time.Duration
	RetryInterval                 time.Duration
	BlobServerEndpoint            *url.URL
	PreconfBlockServerPort        uint64
	PreconfBlockServerJWTSecret   []byte
	PreconfBlockServerCORSOrigins string
	P2PConfigs                    *p2p.Config
	P2PSignerConfigs              p2p.SignerSetup
	PreconfOperatorAddress        common.Address
}

// NewConfigFromCliContext creates a new config instance from
// the command line inputs.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	jwtSecret, err := jwt.ParseSecretFromFile(c.String(flags.JWTSecret.Name))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT secret file: %w", err)
	}

	var (
		p2pSync      = c.Bool(flags.P2PSync.Name)
		l2CheckPoint = c.String(flags.CheckPointSyncURL.Name)
	)

	if p2pSync && len(l2CheckPoint) == 0 {
		return nil, errors.New("empty L2 check point URL")
	}

	var beaconEndpoint string
	if c.IsSet(flags.L1BeaconEndpoint.Name) {
		beaconEndpoint = c.String(flags.L1BeaconEndpoint.Name)
	}

	var blobServerEndpoint *url.URL
	if c.IsSet(flags.BlobServerEndpoint.Name) {
		if blobServerEndpoint, err = url.Parse(
			c.String(flags.BlobServerEndpoint.Name),
		); err != nil {
			return nil, fmt.Errorf("failed to create blob data source: %w", err)
		}
	}

	if beaconEndpoint == "" && blobServerEndpoint == nil {
		return nil, errors.New("empty L1 beacon endpoint, blob server and Social Scan endpoint")
	}

	var preconfBlockServerJWTSecret []byte
	if c.String(flags.PreconfBlockServerJWTSecret.Name) != "" {
		if preconfBlockServerJWTSecret, err = jwt.ParseSecretFromFile(
			c.String(flags.PreconfBlockServerJWTSecret.Name),
		); err != nil {
			return nil, fmt.Errorf("invalid JWT secret file: %w", err)
		}
	}

	// Check P2P network flags and create the P2P configurations.
	var (
		clientConfig = &rpc.ClientConfig{
			L1Endpoint:              c.String(flags.L1HTTPEndpoint.Name),
			L1BeaconEndpoint:        beaconEndpoint,
			L2Endpoint:              c.String(flags.L2WSEndpoint.Name),
			L2CheckPoint:            l2CheckPoint,
			PacayaInboxAddress:      common.HexToAddress(c.String(flags.PacayaInboxAddress.Name)),
			ShastaInboxAddress:      common.HexToAddress(c.String(flags.ShastaInboxAddress.Name)),
			TaikoAnchorAddress:      common.HexToAddress(c.String(flags.TaikoAnchorAddress.Name)),
			PreconfWhitelistAddress: common.HexToAddress(c.String(flags.PreconfWhitelistAddress.Name)),
			L2EngineEndpoint:        c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:               string(jwtSecret),
			Timeout:                 c.Duration(flags.RPCTimeout.Name),
			TaikoWrapperAddress:     common.HexToAddress(c.String(flags.DriverTaikoWrapperAddress.Name)),
			ShastaForkTime:          c.Uint64(flags.ShastaForkTime.Name),
		}
		p2pConfigs    *p2p.Config
		signerConfigs p2p.SignerSetup
	)

	// Create a new RPC client to get the chain IDs.
	rpc, err := rpc.NewClient(context.Background(), clientConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create RPC client: %w", err)
	}
	// Create a new P2P config.
	if p2pConfigs, err = p2pCli.NewConfig(c, &rollup.Config{
		L1ChainID: rpc.L1.ChainID,
		L2ChainID: rpc.L2.ChainID,
		Taiko:     true,
	}); err != nil {
		return nil, fmt.Errorf("failed to create P2P config: %w", err)
	}

	// Create a new P2P signer setup.
	if signerConfigs, err = p2pCli.LoadSignerSetup(c, log.Root()); err != nil {
		return nil, fmt.Errorf("failed to load P2P signer setup: %w", err)
	}

	var preconfOperatorAddress common.Address
	if c.IsSet(p2pFlags.SequencerP2PKeyName) {
		sequencerP2PKey, err := crypto.ToECDSA(common.FromHex(c.String(p2pFlags.SequencerP2PKeyName)))
		if err != nil {
			return nil, fmt.Errorf("failed to parse sequencer P2P key: %w", err)
		}

		preconfOperatorAddress = crypto.PubkeyToAddress(sequencerP2PKey.PublicKey)
	}

	return &Config{
		ClientConfig:                  clientConfig,
		RetryInterval:                 c.Duration(flags.BackOffRetryInterval.Name),
		P2PSync:                       p2pSync,
		P2PSyncTimeout:                c.Duration(flags.P2PSyncTimeout.Name),
		BlobServerEndpoint:            blobServerEndpoint,
		PreconfBlockServerPort:        c.Uint64(flags.PreconfBlockServerPort.Name),
		PreconfBlockServerJWTSecret:   preconfBlockServerJWTSecret,
		PreconfBlockServerCORSOrigins: c.String(flags.PreconfBlockServerCORSOrigins.Name),
		P2PConfigs:                    p2pConfigs,
		P2PSignerConfigs:              signerConfigs,
		PreconfOperatorAddress:        preconfOperatorAddress,
	}, nil
}
