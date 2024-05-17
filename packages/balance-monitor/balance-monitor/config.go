package balanceMonitor

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/balance-monitor/cmd/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	Addresses      []common.Address
	L1RPCUrl       string
	L2RPCUrl       string
	ERC20Addresses []common.Address
	Interval       int
}

func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var addresess []common.Address
	for _, addressStr := range c.StringSlice(flags.Addresses.Name) {
		addresess = append(addresess, common.HexToAddress(addressStr))
	}

	var erc20Addresses []common.Address
	for _, addressStr := range c.StringSlice(flags.ERC20Addresses.Name) {
		erc20Addresses = append(erc20Addresses, common.HexToAddress(addressStr))
	}

	return &Config{
		Addresses:      addresess,
		L1RPCUrl:       c.String(flags.L1RPCUrl.Name),
		L2RPCUrl:       c.String(flags.L2RPCUrl.Name),
		ERC20Addresses: erc20Addresses,
		Interval:       c.Int(flags.Interval.Name),
	}, nil
}
