package main

import (
	"fmt"
	"os"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi"

	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/version"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover"
)

func main() {
	app := cli.NewApp()

	app.Name = "Taiko Clients"
	app.Usage = "The taiko client software command line interface"
	app.Copyright = "Copyright 2021-2022 Taiko Labs"
	app.Version = version.CommitVersion()
	app.Description = "Client software implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "driver",
			Flags:       flags.DriverFlags,
			Usage:       "Starts the driver software",
			Description: "Taiko driver software",
			Action:      utils.SubcommandAction(new(driver.Driver)),
		},
		{
			Name:        "proposer",
			Flags:       flags.ProposerFlags,
			Usage:       "Starts the proposer software",
			Description: "Taiko proposer software",
			Action:      utils.SubcommandAction(new(proposer.Proposer)),
		},
		{
			Name:        "prover",
			Flags:       flags.ProverFlags,
			Usage:       "Starts the prover software",
			Description: "Taiko prover software",
			Action:      utils.SubcommandAction(new(prover.Prover)),
		},
		{
			Name:        "preconfapi",
			Flags:       flags.PreconfAPIFlags,
			Usage:       "Starts the preconfirmation API software",
			Description: "Taiko preconfirmation API software",
			Action:      utils.SubcommandAction(new(preconfapi.PreconfAPI)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
