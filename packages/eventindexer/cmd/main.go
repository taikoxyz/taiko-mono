package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/api"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/disperser"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/generator"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/indexer"
	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.NewApp()

	log.SetOutput(os.Stdout)
	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.

	envFile := os.Getenv("EVENTINDEXER_ENV_FILE")
	if envFile == "" {
		envFile = ".env"
	}

	_ = godotenv.Load(envFile)

	app.Name = "Taiko EventIndexer"
	app.Usage = "The taiko eventindexing software command line interface"
	app.Copyright = "Copyright 2021-2023 Taiko Labs"
	app.Description = "Eventindexer implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "api",
			Flags:       flags.APIFlags,
			Usage:       "Starts the http API software",
			Description: "Taiko eventindexer http API software",
			Action:      utils.SubcommandAction(new(api.API)),
		},
		{
			Name:        "indexer",
			Flags:       flags.IndexerFlags,
			Usage:       "Starts the indexer software",
			Description: "Taiko indexer software",
			Action:      utils.SubcommandAction(new(indexer.Indexer)),
		},
		{
			Name:        "generator",
			Flags:       flags.GeneratorFlags,
			Usage:       "Starts the generator software",
			Description: "Taiko time-series data generator",
			Action:      utils.SubcommandAction(new(generator.Generator)),
		},
		{
			Name:        "disperser",
			Flags:       flags.DisperserFlags,
			Usage:       "Starts the disperser software",
			Description: "Taiko TTKO disperser",
			Action:      utils.SubcommandAction(new(disperser.Disperser)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
