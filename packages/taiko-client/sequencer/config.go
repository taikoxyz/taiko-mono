package sequencer

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Config contains the configurations to initialize a Taiko sequencer.
type Config struct {
	*rpc.ClientConfig
	L1ProposerPrivKey           *ecdsa.PrivateKey
	L2SuggestedFeeRecipient     common.Address
	RetryInterval               time.Duration
	PreconfBlockServerJWTSecret []byte
	PreconfBlockServerAPIURL    string
	PreconfHandoverSkipSlots    uint64
	PreconfOperatorAddress      common.Address
	ProposeBlockTxGasLimit      uint64
	AnchorBlockOffset           uint64
	L2BlockTime                 time.Duration
	HandoverBufferSeconds       time.Duration
	TxmgrConfigs                *txmgr.CLIConfig
}

// NewConfigFromCliContext creates a new config instance from
// the command line inputs.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	jwtSecret, err := jwt.ParseSecretFromFile(c.String(flags.JWTSecret.Name))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT secret file: %w", err)
	}

	beaconEndpoint := c.String(flags.L1BeaconEndpoint.Name)

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
			L1Endpoint:              c.String(flags.L1WSEndpoint.Name),
			L1BeaconEndpoint:        beaconEndpoint,
			L2Endpoint:              c.String(flags.L2WSEndpoint.Name),
			TaikoL1Address:          common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
			TaikoL2Address:          common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
			PreconfWhitelistAddress: common.HexToAddress(c.String(flags.PreconfWhitelistAddress.Name)),
			L2EngineEndpoint:        c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:               string(jwtSecret),
			Timeout:                 c.Duration(flags.RPCTimeout.Name),
		}
	)

	// Create a new RPC client to get the chain IDs.
	rpc, err := rpc.NewClient(context.Background(), clientConfig)
	if err != nil {
		return nil, err
	}

	preconfHandoverSkipSlots := c.Uint64(flags.PreconfHandoverSkipSlots.Name)
	if rpc.L1Beacon != nil && preconfHandoverSkipSlots > rpc.L1Beacon.SlotsPerEpoch {
		return nil, fmt.Errorf(
			"preconf handover skip slots %d is greater than slots per epoch %d",
			preconfHandoverSkipSlots,
			rpc.L1Beacon.SlotsPerEpoch,
		)
	}

	l1ProposerPrivateKey, err := crypto.ToECDSA(common.FromHex(c.String(flags.L1ProposerPrivKey.Name)))
	if err != nil {
		return nil, err
	}

	preconfOperatorAddress := crypto.PubkeyToAddress(l1ProposerPrivateKey.PublicKey)

	return &Config{
		L1ProposerPrivKey:           l1ProposerPrivateKey,
		ClientConfig:                clientConfig,
		RetryInterval:               c.Duration(flags.BackOffRetryInterval.Name),
		PreconfBlockServerJWTSecret: preconfBlockServerJWTSecret,
		PreconfBlockServerAPIURL:    c.String(flags.PreconfAPIURL.Name),
		PreconfHandoverSkipSlots:    preconfHandoverSkipSlots,
		PreconfOperatorAddress:      preconfOperatorAddress,
		ProposeBlockTxGasLimit:      c.Uint64(flags.TxGasLimit.Name),
		L2BlockTime:                 c.Duration(flags.L2BlockTime.Name),
		AnchorBlockOffset:           c.Uint64(flags.AnchorBlockOffset.Name),
		HandoverBufferSeconds:       c.Duration(flags.HandoverBufferSeconds.Name),
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1WSEndpoint.Name),
			l1ProposerPrivateKey,
			c,
		),
	}, nil
}
