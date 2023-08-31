package main

import (
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer"
	"github.com/urfave/cli/v2"
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func main() {
	app := cli.NewApp()

	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.
	_ = godotenv.Load(".env")

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
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
