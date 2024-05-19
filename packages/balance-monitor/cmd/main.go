package main

import (
	"fmt"
	"log"
	"os"

	balanceMonitor "github.com/taikoxyz/taiko-mono/packages/balance-monitor/balance-monitor"
	"github.com/taikoxyz/taiko-mono/packages/balance-monitor/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/balance-monitor/cmd/utils"

	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.NewApp()

	log.SetOutput(os.Stdout)
	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.

	app.Name = "Taiko Balance Monitor"
	app.Usage = "The taiko balance monitor software command line interface"
	app.Copyright = "Copyright 2021-2024 Taiko Labs"
	app.Description = "Bridge balance monitor implementation in Golang"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "balance-monitor",
			Flags:       flags.CommonFlags,
			Usage:       "Starts the balance monitor oftware",
			Description: "Taiko balance monitor",
			Action:      utils.SubcommandAction(new(balanceMonitor.BalanceMonitor)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
