package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/utils"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/healthchecker"
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

	app.Name = "Taiko guardian-prover-health-check"
	app.Usage = "The taiko guardian-prover-health-check software command line interface"
	app.Copyright = "Copyright 2021-2023 Taiko Labs"
	app.Description = "guardian-prover-health-check implementation in Golang for Taiko protocol"
	app.Authors = []*cli.Author{{Name: "Taiko Labs", Email: "info@taiko.xyz"}}
	app.EnableBashCompletion = true

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "healthchecker",
			Flags:       flags.HealthCheckFlags,
			Usage:       "Starts the health check software",
			Description: "Taiko guardian-prover-health-check health checker software",
			Action:      utils.SubcommandAction(new(healthchecker.HealthChecker)),
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
