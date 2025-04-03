package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/consolidator"

	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.NewApp()

	log.SetOutput(os.Stdout)
	// attempt to load a .env file to overwrite CLI flags, but allow it to not
	// exist.

	envFile := os.Getenv("PRECONF_MONITOR_ENV_FILE")
	if envFile == "" {
		envFile = ".env"
	}

	_ = godotenv.Load(envFile)

	app.Name = "Taiko Preconf Monitor"
	app.Usage = "The taiko preconf monitor software command line interface"
	app.Copyright = "Copyright 2021-2025 Taiko Labs"
	app.Description = "Preconf monitor implementation in Golang"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "consolidator",
			Flags:       flags.ConsolidatorFlags,
			Usage:       "Starts the consolidator software",
			Description: "Taiko consolidator monitor",
			Action:      utils.SubcommandAction(new(consolidator.Consolidator)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
