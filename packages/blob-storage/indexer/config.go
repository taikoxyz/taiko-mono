package indexer

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/cmd/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	StartingBlockID *uint64
	RPCURL          string
	BeaconURL       string
	ContractAddress common.Address
	DBHost          string
	DBPort          int
	DBUsername      string
	DBPassword      string
	DBDatabase      string
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var startBlockId *uint64

	if c.IsSet(flags.StartingBlockID.Name) {
		b := c.Uint64(flags.StartingBlockID.DefaultText)
		startBlockId = &b
	}

	return &Config{
		DBHost:          c.String(flags.DBHost.Name),
		DBPort:          c.Int(flags.DBPort.Name),
		DBUsername:      c.String(flags.DBUsername.Name),
		DBPassword:      c.String(flags.DBPassword.Name),
		DBDatabase:      c.String(flags.DBDatabase.Name),
		StartingBlockID: startBlockId,
		RPCURL:          c.String(flags.RPCUrl.Name),
		BeaconURL:       c.String(flags.BeaconURL.Name),
		ContractAddress: common.HexToAddress(c.String(flags.ContractAddress.Name)),
	}, nil
}
