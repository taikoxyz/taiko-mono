package balanceMonitor

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/balance-monitor/cmd/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	Addresses []common.Address
	L1RPCUrl  string
	L2RPCUrl  string
}

func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var addresess []common.Address
	for _, addressStr := range c.StringSlice(flags.Addresses.Name) {
		addresess = append(addresess, common.HexToAddress(addressStr))
	}

	return &Config{
		Addresses: addresess,
		L1RPCUrl:  c.String(flags.L1RPCUrl.Name),
		L2RPCUrl:  c.String(flags.L2RPCUrl.Name),
	}, nil
}
