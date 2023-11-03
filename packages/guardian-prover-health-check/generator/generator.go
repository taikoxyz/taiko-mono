package generator

import (
	"context"

	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

// Generator is a subcommand which is intended to be run on an interval, like
// a cronjob, to parse the indexed data from the database, and generate
// time series data that can easily be displayed via charting libraries.
type Generator struct {
	db DB
}

func (g *Generator) InitFromCli(ctx context.Context, c *cli.Context) error {
	config, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, g, config)
}

func InitFromConfig(ctx context.Context, g *Generator, cfg *Config) error {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	g.db = db

	return nil
}

func (g *Generator) Name() string {
	return "generator"
}

func (g *Generator) Start() error {
	slog.Info("generating uptime availability statistics")

	if err := g.generateUptimeAvailabilityStats(context.Background()); err != nil {
		return err
	}

	return nil
}

func (g *Generator) Close(ctx context.Context) {
	sqlDB, err := g.db.DB()
	if err != nil {
		slog.Error("error getting sqldb when closing generator", "err", err.Error())
	}

	if err := sqlDB.Close(); err != nil {
		slog.Error("error closing sqlbd connection", "err", err.Error())
	}
}

func (g *Generator) generateUptimeAvailabilityStats(ctx context.Context) error {
	return nil
}
