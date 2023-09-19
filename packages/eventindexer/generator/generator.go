package generator

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/shopspring/decimal"
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

		if err := g.deleteTimeSeriesData(context.Background()); err != nil {
			return err
		}
	}

	slog.Info("generating time series data")

	if err := g.generateTimeSeriesData(context.Background()); err != nil {
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

func (g *Generator) deleteTimeSeriesData(ctx context.Context) error {
	deleteStmt := "DELETE FROM time_series_data;"
	if err := g.db.GormDB().Exec(deleteStmt).Error; err != nil {
		return err
	}

	return nil
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

	startingDate, err := g.getStartingDateByTask(ctx, task)
	if err != nil {
		return err
	}

	currentDate := g.getCurrentDate()
	if startingDate.Compare(currentDate) == 0 {
		slog.Info(
			"data already generated up-to-date for task",
			"task", task,
			"date", startingDate.Format("2006-01-02"),
			"currentDate", currentDate.Format("2006-01-02"),
		)

		return nil
	}

	// Loop through each date from latestDate to currentDate
	for d := startingDate; d.Before(currentDate); d = d.AddDate(0, 0, 1) {
		slog.Info("Processing", "task", task, "date", d.Format("2006-01-02"), "currentDate", currentDate.Format("2006-01-02"))

		result, err := g.queryByTask(task, d)
		if err != nil {
			slog.Info("Query failed", "task", task, "date", d.Format("2006-01-02"), "error", err.Error())
			return err
		}

		slog.Info("Query successful", "task", task, "date", d.Format("2006-01-02"), "result", result.String())

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

// getStartingDateByTask returns first required time series data, one after the latest date entry,
// or the genesis date.
func (g *Generator) getStartingDateByTask(ctx context.Context, task string) (time.Time, error) {
	var latestDateString string

	var nextRequiredDate time.Time

	q := `SELECT date FROM time_series_data WHERE task = ? ORDER BY date DESC LIMIT 1;`

	err := g.db.GormDB().Raw(q, task).Scan(&latestDateString).Error

	slog.Info("latestDateString", "task", task, "date", latestDateString)

	if err != nil || latestDateString == "" {
		nextRequiredDate = g.genesisDate
	} else {
		latestDate, err := time.Parse("2006-01-02", latestDateString)
		if err != nil {
			return time.Time{}, err
		}

		nextRequiredDate = latestDate.AddDate(0, 0, 1)
	}

	slog.Info("next required date for task", "task", task, "nextRequiredDate", nextRequiredDate.Format("2006-01-02"))

	return nextRequiredDate, nil
}

// getCurrentDate returns the current date in YYYY-MM-DD format
func (g *Generator) getCurrentDate() time.Time {
	// Get current date
	currentTime := time.Now().UTC()
	currentDate := time.Date(currentTime.Year(), currentTime.Month(), currentTime.Day(), 0, 0, 0, 0, time.UTC)

	return currentDate
}

// nolint: funlen, gocognit
// queryByTask runs a database query which should return result data based on the
// task
func (g *Generator) queryByTask(task string, date time.Time) (decimal.Decimal, error) {
	dateString := date.Format("2006-01-02")

	var result decimal.Decimal

	var err error

	switch task {
	case tasks.ProposerRewardsPerDay:
		query := "SELECT COALESCE(SUM(proposer_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, dateString).
			Scan(&result).Error

	case tasks.TotalProposerRewards:
		var dailyProposerRewards decimal.NullDecimal

		query := "SELECT COALESCE(SUM(proposer_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, dateString).
			Scan(&dailyProposerRewards).Error

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyProposerRewards.Decimal)

	case tasks.TotalProofRewards:
		var dailyProofRewards decimal.NullDecimal

		query := "SELECT COALESCE(SUM(proof_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, dateString).
			Scan(&dailyProofRewards).Error

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyProofRewards.Decimal)
	case tasks.ProofRewardsPerDay:
		query := "SELECT COALESCE(SUM(proof_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, dateString).
			Scan(&result).Error
	case tasks.BridgeMessagesSentPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &result)
	case tasks.TotalBridgeMessagesSent:
		var dailyMsgSentCount decimal.NullDecimal

		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &dailyMsgSentCount)
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyMsgSentCount.Decimal)
	case tasks.ProposeBlockTxPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &result)
	case tasks.TotalProposeBlockTx:
		var dailyProposerCount decimal.NullDecimal

		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &dailyProposerCount)
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyProposerCount.Decimal)
	case tasks.UniqueProposersPerDay:
		query := "SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProposed, dateString).
			Scan(&result).Error
	case tasks.TotalUniqueProposers:
		query := `SELECT COUNT(DISTINCT address) FROM events WHERE event = ?`

		err = g.db.GormDB().Raw(
			query,
			eventindexer.EventNameBlockProposed,
		).Scan(&result).Error
		if err != nil {
			return result, err
		}
	case tasks.UniqueProversPerDay:
		query := "SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProven, dateString).
			Scan(&result).Error
	case tasks.TotalUniqueProvers:
		query := `SELECT COUNT(DISTINCT address) FROM events WHERE event = ?`

		err = g.db.GormDB().Raw(
			query,
			eventindexer.EventNameBlockProven,
		).Scan(&result).Error
		if err != nil {
			return result, err
		}
	case tasks.ProveBlockTxPerDay:
		query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockProven, dateString).
			Scan(&result).Error
	case tasks.TotalProveBlockTx:
		var dailyProveBlockCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, eventindexer.EventNameBlockProven, dateString).Scan(&dailyProveBlockCount).Error
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyProveBlockCount.Decimal)
	case tasks.AccountsPerDay:
		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalAccounts:
		var dailyAccountsCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyAccountsCount).Error
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyAccountsCount.Decimal)
	case tasks.BlocksPerDay:
		query := `SELECT COUNT(*) FROM blocks WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalBlocks:
		var dailyBlockCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM blocks WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyBlockCount).Error
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyBlockCount.Decimal)
	case tasks.TransactionsPerDay:
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalTransactions:
		var dailyTxCount decimal.NullDecimal

		// get current days txs, get previous entry for the time series data, add them together.

		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyTxCount).Error
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyTxCount.Decimal)
	case tasks.ContractDeploymentsPerDay:
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ? AND contract_address != ?`
		err = g.db.GormDB().Raw(query, dateString, ZeroAddress.Hex()).Scan(&result).Error
	case tasks.TotalContractDeployments:
		var dailyContractCount decimal.NullDecimal

		// get current days txs, get previous entry for the time series data, add them together.
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ? AND contract_address != ?`

		err = g.db.GormDB().Raw(query, dateString, ZeroAddress.Hex()).Scan(&dailyContractCount).Error
		if err != nil {
			return result, err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date)
		if err != nil {
			return result, err
		}

		result = tsdResult.Decimal.Add(dailyContractCount.Decimal)
	default:
		return result, errors.New("task not supported")
	}

	if err != nil {
		return result, err
	}

	return result, nil
}

// previousDayTsdResultByTask returns the previous day's time series data, based on
// task and time passed in.
func (g *Generator) previousDayTsdResultByTask(task string, date time.Time) (decimal.NullDecimal, error) {
	var tsdResult decimal.NullDecimal

	tsdQuery := `SELECT value FROM time_series_data WHERE task = ? AND date = ?`

	err := g.db.GormDB().Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02")).Scan(&tsdResult).Error
	if err != nil {
		return tsdResult, err
	}

	if !tsdResult.Valid {
		return decimal.NullDecimal{
			Valid:   true,
			Decimal: decimal.Zero,
		}, nil
	}

	return tsdResult, nil
}

// eventCount is a helper method to query the database for the count of a specific event
// based on the date.
func (g *Generator) eventCount(task string, date time.Time, event string, result interface{}) error {
	query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"

	return g.db.GormDB().
		Raw(query, event, date.Format("2006-01-02")).
		Scan(result).Error
}
