package generator

import (
	"context"
	"os"
	"time"

	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

type generatorQueryResult struct {
	Requests           int
	SuccessfulRequests int
}

// Generator is a subcommand which is intended to be run on an interval, like
// a cronjob, to parse the indexed data from the database, and generate
// time series data that can easily be displayed via charting libraries.
type Generator struct {
	db          DB
	genesisDate time.Time
	regenerate  bool
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
	g.genesisDate = cfg.GenesisDate
	g.regenerate = cfg.Regenerate

	return nil
}

func (g *Generator) Name() string {
	return "generator"
}

func (g *Generator) Start() error {
	if g.regenerate {
		slog.Info("regenerating, deleting existing data")

		if err := g.deleteUptimeAvailabilityStats(context.Background()); err != nil {
			return err
		}
	}

	slog.Info("generating uptime availability statistics")

	if err := g.generateUptimeAvailabilityStats(context.Background()); err != nil {
		return err
	}

	os.Exit(0)

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
	guardianProverIDs, err := g.getGuardianProverIDs(ctx)
	if err != nil {
		return err
	}

	for _, guardianProverID := range guardianProverIDs {
		if err := g.generateByGuardianProverID(ctx, guardianProverID); err != nil {
			slog.Error("error generating", "guardianProverID", guardianProverID, "error", err.Error())
			return err
		}
	}

	return nil
}

func (g *Generator) getGuardianProverIDs(ctx context.Context) ([]int, error) {
	var guardianProverIDs []int

	q := `SELECT DISTINCT guardian_prover_id FROM health_checks;`

	err := g.db.GormDB().Raw(q).Scan(&guardianProverIDs).Error

	if err != nil {
		return nil, err
	}

	slog.Info("guardian prover IDs found", "guardianProverIDs", guardianProverIDs)

	return guardianProverIDs, nil
}

// generateByTask generates uptime availability data for each day in between the current date
// and the most recently generated data, for the given guardian prover.
func (g *Generator) generateByGuardianProverID(ctx context.Context, guardianProverID int) error {
	slog.Info("generating", "guardianProverID", guardianProverID)

	startingDate, err := g.getStartingDate(ctx, guardianProverID)
	if err != nil {
		return err
	}

	currentDate := g.getCurrentDate()
	if startingDate.Compare(currentDate) == 0 {
		slog.Info(
			"data already generated up-to-date for id",
			"guardianProverID", guardianProverID,
			"date", startingDate.Format("2006-01-02"),
			"currentDate", currentDate.Format("2006-01-02"),
		)

		return nil
	}

	// Loop through each date from latestDate to currentDate
	for d := startingDate; d.Before(currentDate); d = d.AddDate(0, 0, 1) {
		slog.Info("Processing",
			"guardianProverID", guardianProverID,
			"date", d.Format("2006-01-02"),
			"currentDate", currentDate.Format("2006-01-02"),
		)

		result, err := g.query(ctx, guardianProverID, d)
		if err != nil {
			slog.Info("Query failed", "guardianProverID", guardianProverID, "date", d.Format("2006-01-02"), "error", err.Error())
			return err
		}

		var uptime float64 = 0
		if result.Requests != 0 && result.SuccessfulRequests != 0 {
			uptime = (float64(result.Requests) / float64(result.SuccessfulRequests)) * 100
		}

		slog.Info("Query successful",
			"guardianProverID", guardianProverID,
			"date", d.Format("2006-01-02"),
			"numRequests", result.Requests,
			"numSuccessfulRequests", result.SuccessfulRequests,
			"uptime", uptime,
		)

		insertStmt := `
		INSERT INTO stats(guardian_prover_id, requests, successful_requests, uptime, date)
		VALUES (?, ?, ?, ?, ?)`

		err = g.db.GormDB().Exec(
			insertStmt,
			guardianProverID,
			result.Requests,
			result.SuccessfulRequests,
			uptime,
			d.Format("2006-01-02"),
		).Error
		if err != nil {
			slog.Info("Insert failed",
				"guardianProverID", guardianProverID,
				"date", d.Format("2006-01-02"),
				"error", err.Error(),
			)

			return err
		}

		slog.Info("Processed", "guardianProverID", guardianProverID, "date", d.Format("2006-01-02"))
	}

	return nil
}

func (g *Generator) query(ctx context.Context, guardianProverID int, date time.Time) (*generatorQueryResult, error) {
	dateString := date.Format("2006-01-02")

	var numRequests int

	var numSuccessfulRequests int

	query := "SELECT count(*) FROM health_checks WHERE guardian_prover_id = ? AND DATE(created_at) = ?"
	err := g.db.GormDB().
		Raw(query, guardianProverID, dateString).
		Scan(&numRequests).Error

	if err != nil {
		return nil, err
	}

	query = "SELECT count(*) FROM health_checks WHERE guardian_prover_id = ? AND alive = 1 AND DATE(created_at) = ?"
	err = g.db.GormDB().
		Raw(query, guardianProverID, dateString).
		Scan(&numSuccessfulRequests).Error

	if err != nil {
		return nil, err
	}

	result := &generatorQueryResult{
		Requests:           numRequests,
		SuccessfulRequests: numSuccessfulRequests,
	}

	return result, nil
}

// getCurrentDate returns the current date in YYYY-MM-DD format
func (g *Generator) getCurrentDate() time.Time {
	// Get current date
	currentTime := time.Now().UTC()
	currentDate := time.Date(currentTime.Year(), currentTime.Month(), currentTime.Day(), 0, 0, 0, 0, time.UTC)

	return currentDate
}

// getStartingDate returns first required data to be generated, one after the latest date entry,
// or the genesis date.
func (g *Generator) getStartingDate(ctx context.Context, guardianProverID int) (time.Time, error) {
	var latestDateString string

	var nextRequiredDate time.Time

	q := `SELECT date FROM stats WHERE guardian_prover_id = ? ORDER BY date DESC LIMIT 1;`

	err := g.db.GormDB().Raw(q, guardianProverID).Scan(&latestDateString).Error

	slog.Info("latestDateString", "guardianProverID", guardianProverID, "date", latestDateString)

	if err != nil || latestDateString == "" {
		nextRequiredDate = g.genesisDate
	} else {
		latestDate, err := time.Parse("2006-01-02", latestDateString)
		if err != nil {
			return time.Time{}, err
		}

		nextRequiredDate = latestDate.AddDate(0, 0, 1)
	}

	slog.Info("next required date for task",
		"guardianProverID", guardianProverID,
		"nextRequiredDate", nextRequiredDate.Format("2006-01-02"),
	)

	return nextRequiredDate, nil
}

func (g *Generator) deleteUptimeAvailabilityStats(ctx context.Context) error {
	deleteStmt := "DELETE FROM stats;"
	if err := g.db.GormDB().Exec(deleteStmt).Error; err != nil {
		return err
	}

	return nil
}
