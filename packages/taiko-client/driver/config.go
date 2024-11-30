package driver

import (
	"errors"
	"fmt"
	"net/url"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Config contains the configurations to initialize a Taiko driver.
type Config struct {
	*rpc.ClientConfig
	P2PSync                    bool
	P2PSyncTimeout             time.Duration
	RetryInterval              time.Duration
	MaxExponent                uint64
	BlobServerEndpoint         *url.URL
	SocialScanEndpoint         *url.URL
	SoftBlockServerPort        uint64
	SoftBlockServerJWTSecret   []byte
	SoftBlockServerCORSOrigins string
	SoftBlockServerCheckSig    bool
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
			return nil, err
		}
	}

	var socialScanEndpoint *url.URL
	if c.IsSet(flags.SocialScanEndpoint.Name) {
		if socialScanEndpoint, err = url.Parse(
			c.String(flags.SocialScanEndpoint.Name),
		); err != nil {
			return nil, err
		}
	}

	if beaconEndpoint == "" && blobServerEndpoint == nil && socialScanEndpoint == nil {
		return nil, errors.New("empty L1 beacon endpoint, blob server and Social Scan endpoint")
	}

	var softBlockServerJWTSecret []byte
	if c.String(flags.SoftBlockServerJWTSecret.Name) != "" {
		if softBlockServerJWTSecret, err = jwt.ParseSecretFromFile(
			c.String(flags.SoftBlockServerJWTSecret.Name),
		); err != nil {
			return nil, fmt.Errorf("invalid JWT secret file: %w", err)
		}
	}

	var timeout = c.Duration(flags.RPCTimeout.Name)
	return &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:       c.String(flags.L1WSEndpoint.Name),
			L1BeaconEndpoint: beaconEndpoint,
			L2Endpoint:       c.String(flags.L2WSEndpoint.Name),
			L2CheckPoint:     l2CheckPoint,
			TaikoL1Address:   common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
			TaikoL2Address:   common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
			L2EngineEndpoint: c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:        string(jwtSecret),
			Timeout:          timeout,
		},
		RetryInterval:              c.Duration(flags.BackOffRetryInterval.Name),
		P2PSync:                    p2pSync,
		P2PSyncTimeout:             c.Duration(flags.P2PSyncTimeout.Name),
		MaxExponent:                c.Uint64(flags.MaxExponent.Name),
		BlobServerEndpoint:         blobServerEndpoint,
		SocialScanEndpoint:         socialScanEndpoint,
		SoftBlockServerPort:        c.Uint64(flags.SoftBlockServerPort.Name),
		SoftBlockServerJWTSecret:   softBlockServerJWTSecret,
		SoftBlockServerCORSOrigins: c.String(flags.SoftBlockServerCORSOrigins.Name),
		SoftBlockServerCheckSig:    c.Bool(flags.SoftBlockServerCheckSig.Name),
	}, nil
}
