package generator

import (
	"context"
	"log/slog"
	"strconv"
	"syscall"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/tasks"
	"github.com/urfave/cli/v2"
)

var (
	oneDay = 24 * time.Hour
)

type Generator struct {
	db          DB
	genesisDate time.Time
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

	return nil
}

func (g *Generator) Name() string {
	return "generator"
}

func (g *Generator) Start() error {
	slog.Info("generating time series data")
	if err := g.generateTimeSeriesData(context.Background()); err != nil {
		return err
	}

	syscall.Kill(syscall.Getpid(), syscall.SIGINT)

	return nil
}

func (g *Generator) Close(ctx context.Context) {

}

func (g *Generator) generateTimeSeriesData(ctx context.Context) error {
	for _, task := range tasks.Tasks {
		if err := g.generateByTask(ctx, task); err != nil {
			slog.Error("error generating for task", "task", task, "error", err.Error())
			return err
		}
	}

	return nil
}

func (g *Generator) generateByTask(ctx context.Context, task string) error {
	slog.Info("generating for task", "task", task)

	latestDate, err := g.getLatestDateByTask(ctx, task)
	if err != nil {
		return err
	}

	currentDate := g.getCurrentDate()

	// Loop through each date from latestDate to currentDate
	for d := latestDate; d.Before(currentDate); d = d.AddDate(0, 0, 1) {
		slog.Info("Processing", "task", task, "date", d.Format("2006-01-02"))

		result, err := g.queryByTask(task, d)
		if err != nil {
			slog.Info("Query failed", "task", task, "date", d.Format("2006-01-02"), "error", err.Error())
			return err
		}

		slog.Info("Query successful", "task", task, "date", d.Format("2006-01-02"), "result", result)

		insertStmt := `
		INSERT INTO time_series_data(task, value, date)
		VALUES (?, ?, ?)`

		err = g.db.GormDB().Exec(insertStmt, task, result, d.Format("2006-01-02")).Error
		if err != nil {
			slog.Info("Insert failed", "task", task, "date", d.Format("2006-01-02"), "error", err.Error())
			return err
		}

		slog.Info("Processed", "task", task, "date", d.Format("2006-01-02"))
	}

	return nil
}

func (g *Generator) getLatestDateByTask(ctx context.Context, task string) (time.Time, error) {
	var latestDateString string

	var latestDate time.Time

	q := `SELECT date FROM time_series_data WHERE task = ? ORDER BY date DESC LIMIT 1;`

	err := g.db.GormDB().Raw(q, task).Scan(&latestDateString).Error

	slog.Info("latestDateString", "date", latestDateString)

	if err != nil || latestDateString == "" {
		latestDate = g.genesisDate
	} else {
		latestDate, err = time.Parse("2006-01-02", latestDateString)
	}

	if err != nil {
		return time.Time{}, err
	}

	slog.Info("latest date for task", "task", task, "latestDate", latestDate.Format("2006-01-02"))

	return latestDate, nil
}

func (g *Generator) getCurrentDate() time.Time {
	// Get current date
	currentTime := time.Now()
	currentDate := time.Date(currentTime.Year(), currentTime.Month(), currentTime.Day(), 0, 0, 0, 0, time.UTC)

	return currentDate

}

func (g *Generator) queryByTask(task string, date time.Time) (string, error) {
	dateString := date.Format("2006-01-02")

	var result string

	var err error

	switch task {
	case tasks.TransactionsByDay:
		query := `SELECT 
		COUNT(*)
	FROM 
		transactions
	WHERE 
		DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalTransactions:
		var dailyTxCount int
		// get current days txs, get previous entry for the time series data, add them together.
		query := `SELECT 
		COUNT(*)
	FROM 
		transactions
	WHERE 
		DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyTxCount).Error
		if err != nil {
			return "", err
		}

		var tsdResult int
		tsdQuery := `SELECT value FROM time_series_data WHERE task = ? AND date = ?`

		err = g.db.GormDB().Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02")).Scan(&tsdResult).Error
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyTxCount + tsdResult)
	default:
	}

	if err != nil {
		return "", err
	}

	return result, nil
}
