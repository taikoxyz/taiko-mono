package consolidator

import (
	"crypto/ecdsa"
	"fmt"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/preconf-monitor/pkg/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	WhitelistAddress common.Address
	L1RPCUrl         string
	Interval         time.Duration
	PrivateKey       *ecdsa.PrivateKey

	TxmgrConfigs *txmgr.CLIConfig
}

func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	wl := common.HexToAddress(c.String(flags.WhitelistAddress.Name))

	privateKey, err := crypto.ToECDSA(
		common.Hex2Bytes(c.String(flags.PrivateKey.Name)),
	)
	if err != nil {
		return nil, fmt.Errorf("invalid privateKey: %w", err)
	}

	return &Config{
		L1RPCUrl:         c.String(flags.L1RPCUrl.Name),
		Interval:         c.Duration(flags.Interval.Name),
		WhitelistAddress: wl,
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1RPCUrl.Name),
			privateKey,
			c,
		),
	}, nil
}
