package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/indexer"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/server"
	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.NewApp()

	log.SetOutput(os.Stdout)
	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.

	envFile := os.Getenv("ENV_FILE")
	if envFile == "" {
		envFile = ".env"
	}

	_ = godotenv.Load(envFile)

	app.Name = "Taiko Blob Catcher"
	app.Usage = "The taiko blob catcher softwares command line interface"
	app.Copyright = "Copyright 2021-2024 Taiko Labs"
	app.Description = "Blob catcher implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "indexer",
			Flags:       flags.IndexerFlags,
			Usage:       "Starts the blobcatcher software",
			Description: "Taiko blobcatcher indexer software",
			Action:      utils.SubcommandAction(new(indexer.Indexer)),
		},
		{
			Name:        "server",
			Flags:       flags.ServerFlags,
			Usage:       "Starts the server software",
			Description: "Taiko blobcatcher server software",
			Action:      utils.SubcommandAction(new(server.Server)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
