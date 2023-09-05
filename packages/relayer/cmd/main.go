package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/processor"
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
	app.Usage = "The taiko relayer softwares command line interface"
	app.Copyright = "Copyright 2021-2023 Taiko Labs"
	app.Description = "Bridge relayer implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
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
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
