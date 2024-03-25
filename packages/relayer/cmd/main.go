package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/relayer/api"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/processor"
	"github.com/taikoxyz/taiko-mono/packages/relayer/watchdog"
	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.NewApp()

	log.SetOutput(os.Stdout)
	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.

	envFile := os.Getenv("RELAYER_ENV_FILE")
	if envFile == "" {
		envFile = ".env"
	}

	_ = godotenv.Load(envFile)

	app.Name = "Taiko Relayer"
	app.Usage = "The taiko relayer software command line interface"
	app.Copyright = "Copyright 2021-2024 Taiko Labs"
	app.Description = "Bridge relayer implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "api",
			Flags:       flags.APIFlags,
			Usage:       "Starts the relayer http API software",
			Description: "Taiko relayer http API software",
			Action:      utils.SubcommandAction(new(api.API)),
		},
		{
			Name:        "indexer",
			Flags:       flags.IndexerFlags,
			Usage:       "Starts the indexer software",
			Description: "Taiko relayer indexer software",
			Action:      utils.SubcommandAction(new(indexer.Indexer)),
		},
		{
			Name:        "processor",
			Flags:       flags.ProcessorFlags,
			Usage:       "Starts the processor software",
			Description: "Taiko relayer processor software",
			Action:      utils.SubcommandAction(new(processor.Processor)),
		},
		{
			Name:        "watchdog",
			Flags:       flags.WatchdogFlags,
			Usage:       "Starts the watchdog software",
			Description: "Taiko relayer watchdog software",
			Action:      utils.SubcommandAction(new(watchdog.Watchdog)),
		},
		{
			Name:        "bridge",
			Flags:       flags.BridgeFlags,
			Usage:       "Starts the bridge software",
			Description: "Taiko relayer bridge software",
			Action:      utils.SubcommandAction(new(bridge.Bridge)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
