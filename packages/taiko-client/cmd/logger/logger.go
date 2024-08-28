package logger

import (
	"os"

	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

// InitLogger initializes the root logger with the command line flags.
func InitLogger(c *cli.Context) {
	var (
		slogVerbosity = log.FromLegacyLevel(c.Int(flags.Verbosity.Name))
	)

	if c.Bool(flags.LogJSON.Name) {
		glogger := log.NewGlogHandler(log.NewGlogHandler(log.JSONHandler(os.Stdout)))
		glogger.Verbosity(slogVerbosity)
		log.SetDefault(log.NewLogger(glogger))
	} else {
		glogger := log.NewGlogHandler(log.NewTerminalHandler(os.Stdout, false))
		glogger.Verbosity(slogVerbosity)
		log.SetDefault(log.NewLogger(glogger))
	}
}
