package generator

import (
	"context"
	"errors"
	"log/slog"
	"strconv"
	"syscall"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/tasks"
	"github.com/urfave/cli/v2"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

// Generator is a subcommand which is intended to be run on an interval, like
// a cronjob, to parse the indexed data from the database, and generate
// time series data that can easily be displayed via charting libraries.
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

	if err := syscall.Kill(syscall.Getpid(), syscall.SIGTERM); err != nil {
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
		slog.Error("error closing sqlbd connecting", "err", err.Error())
	}
}

// generateTimeSeriesData iterates over each task and generates time series data.
func (g *Generator) generateTimeSeriesData(ctx context.Context) error {
	for _, task := range tasks.Tasks {
		if err := g.generateByTask(ctx, task); err != nil {
			slog.Error("error generating for task", "task", task, "error", err.Error())
			return err
		}
	}

	return nil
}

// generateByTask generates time series data for each day in between the current date
// and the most recently generated time series data, for the given task.
func (g *Generator) generateByTask(ctx context.Context, task string) error {
	slog.Info("generating for task", "task", task)

	latestDate, err := g.getLatestDateByTask(ctx, task)
	if err != nil {
		return err
	}

	currentDate := g.getCurrentDate()
	if latestDate.AddDate(0, 0, 1).Compare(currentDate) == 0 {
		slog.Info("data already generated up-to-date for task", "task", task, "date", latestDate.Format("2006-01-02"))
		return nil
	}

	// Loop through each date from latestDate to currentDate
	for d := latestDate; d.Before(currentDate); d = d.AddDate(0, 0, 1) {
		slog.Info("Processing", "task", task, "date", d.Format("2006-01-02"), "currentDate", currentDate.Format("2006-01-02"))

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

// getLatestDateByTask returns the last time time series data has been generated
// for the given task.
func (g *Generator) getLatestDateByTask(ctx context.Context, task string) (time.Time, error) {
	var latestDateString string

	var latestDate time.Time

	q := `SELECT date FROM time_series_data WHERE task = ? ORDER BY date DESC LIMIT 1;`

	err := g.db.GormDB().Raw(q, task).Scan(&latestDateString).Error

	slog.Info("latestDateString", "task", task, "date", latestDateString)

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

// getCurrentDate returns the current date in YYYY-MM-DD format
func (g *Generator) getCurrentDate() time.Time {
	// Get current date
	currentTime := time.Now()
	currentDate := time.Date(currentTime.Year(), currentTime.Month(), currentTime.Day(), 0, 0, 0, 0, time.UTC)

	return currentDate
}

// nolint: funlen
// queryByTask runs a database query which should return result data based on the
// task
func (g *Generator) queryByTask(task string, date time.Time) (string, error) {
	dateString := date.Format("2006-01-02")

	var result string

	var err error

	switch task {
	case tasks.BridgeMessagesSentPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &result)
	case tasks.TotalBridgeMessagesSent:
		var dailyMsgSentCount int

		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &dailyMsgSentCount)
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyMsgSentCount + tsdResult)
	case tasks.ProposeBlockTxPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &result)
	case tasks.TotalProposeBlockTx:
		var dailyProposerCount int

		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &dailyProposerCount)
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyProposerCount + tsdResult)
	case tasks.UniqueProposersPerDay:
		query := "SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, date).
			Scan(&result).Error
	case tasks.TotalUniqueProposers:
		var dailyProposerCount int

		query := `SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, eventindexer.EventNameBlockProposed, dateString).Scan(&dailyProposerCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyProposerCount + tsdResult)
	case tasks.UniqueProversPerDay:
		query := "SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProven, date).
			Scan(&result).Error
	case tasks.TotalUniqueProvers:
		var dailyProposerCount int

		query := `SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, eventindexer.EventNameBlockProven, dateString).Scan(&dailyProposerCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyProposerCount + tsdResult)
	case tasks.ProveBlockTxPerDay:
		query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProven, date).
			Scan(&result).Error
	case tasks.TotalProveBlockTx:
		var dailyProposerCount int

		query := `SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, eventindexer.EventNameBlockProven, dateString).Scan(&dailyProposerCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyProposerCount + tsdResult)
	case tasks.AccountsPerDay:
		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalAccounts:
		var dailyAccountsCount int

		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyAccountsCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyAccountsCount + tsdResult)
	case tasks.BlocksPerDay:
		query := `SELECT COUNT(*) FROM blocks WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalBlocks:
		var dailyBlockCount int

		query := `SELECT COUNT(*) FROM blocks WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyBlockCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyBlockCount + tsdResult)
	case tasks.TransactionsPerDay:
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalTransactions:
		var dailyTxCount int

		// get current days txs, get previous entry for the time series data, add them together.

		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyTxCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyTxCount + tsdResult)
	case tasks.ContractDeploymentsPerDay:
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ? AND contract_address != ?`
		err = g.db.GormDB().Raw(query, dateString, ZeroAddress).Scan(&result).Error
	case tasks.TotalContractDeployments:
		var dailyContractCount int

		// get current days txs, get previous entry for the time series data, add them together.
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ? AND contract_address != ?`

		err = g.db.GormDB().Raw(query, dateString, ZeroAddress).Scan(&dailyContractCount).Error
		if err != nil {
			return "", err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return "", err
		}

		result = strconv.Itoa(dailyContractCount + tsdResult)
	default:
		return "", errors.New("task not supported")
	}

	if err != nil {
		return "", err
	}

	return result, nil
}

// previousDayTsdResultByTask returns the previous day's time series data, based on
// task and time passed in.
func (g *Generator) previousDayTsdResultByTask(task string, date time.Time) (int, error) {
	var tsdResult int

	tsdQuery := `SELECT value FROM time_series_data WHERE task = ? AND date = ?`

	err := g.db.GormDB().Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02")).Scan(&tsdResult).Error
	if err != nil {
		return 0, err
	}

	return tsdResult, nil
}

// eventCount is a helper method to query the database for the count of a specific event
// based on the date.
func (g *Generator) eventCount(task string, date time.Time, event string, result interface{}) error {
	query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"

	return g.db.GormDB().
		Raw(query, event, date).
		Scan(result).Error
}
