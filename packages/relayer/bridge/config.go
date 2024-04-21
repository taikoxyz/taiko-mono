package bridge

import (
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	// address configs
	SrcBridgeAddress  common.Address
	DestBridgeAddress common.Address

	// private key
	BridgePrivateKey *ecdsa.PrivateKey

	// processing configs
	Confirmations        uint64
	ConfirmationsTimeout uint64
	EnableTaikoL2        bool

	// backoff configs
	BackoffRetryInterval uint64
	BackOffMaxRetrys     uint64

	// rpc configs
	SrcRPCUrl        string
	DestRPCUrl       string
	ETHClientTimeout uint64

	// BridgeMessage
	BridgeMessageValue *big.Int
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	bridgePrivateKey, err := crypto.ToECDSA(
		common.Hex2Bytes(c.String(flags.BridgePrivateKey.Name)),
	)
	if err != nil {
		return nil, fmt.Errorf("invalid bridgePrivateKey: %w", err)
	}

	bridgeMessageValue, ok := new(big.Int).SetString(c.String(flags.BridgeMessageValue.Name), 10)
	if !ok {
		return nil, errors.New("invalid bridgeMessageValue")
	}

	return &Config{
		BridgePrivateKey:     bridgePrivateKey,
		DestBridgeAddress:    common.HexToAddress(c.String(flags.DestBridgeAddress.Name)),
		SrcBridgeAddress:     common.HexToAddress(c.String(flags.SrcBridgeAddress.Name)),
		SrcRPCUrl:            c.String(flags.SrcRPCUrl.Name),
		DestRPCUrl:           c.String(flags.DestRPCUrl.Name),
		Confirmations:        c.Uint64(flags.Confirmations.Name),
		ConfirmationsTimeout: c.Uint64(flags.ConfirmationTimeout.Name),
		EnableTaikoL2:        c.Bool(flags.EnableTaikoL2.Name),
		BackoffRetryInterval: c.Uint64(flags.BackOffRetryInterval.Name),
		BackOffMaxRetrys:     c.Uint64(flags.BackOffMaxRetrys.Name),
		ETHClientTimeout:     c.Uint64(flags.ETHClientTimeout.Name),
		BridgeMessageValue:   bridgeMessageValue,
	}, nil
}
