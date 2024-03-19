package generator

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/shopspring/decimal"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/tasks"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"
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

		err := g.queryByTask(task, d)
		if err != nil {
			slog.Info("Query failed", "task", task, "date", d.Format("2006-01-02"), "error", err.Error())
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
func (g *Generator) queryByTask(task string, date time.Time) error {
	dateString := date.Format("2006-01-02")

	var result decimal.Decimal

	var err error

	switch task {
	case tasks.TotalTransitionProvedByTier:
		var tiers []uint16 = make([]uint16, 0)

		query := "SELECT DISTINCT tier FROM events WHERE event = ? AND tier IS NOT NULL;"

		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionProved).
			Scan(&tiers).Error
		if err != nil {
			return err
		}

		slog.Info("tiers", "tiers", tiers)

		for _, tier := range tiers {
			t := tier

			var dailyCountByTier decimal.NullDecimal

			// nolint: lll
			query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND tier = ?"
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameTransitionProved, dateString, t).
				Scan(&dailyCountByTier).Error

			if err != nil {
				return err
			}

			tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, &t)
			if err != nil {
				return err
			}

			result := tsdResult.Decimal.Add(dailyCountByTier.Decimal)

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", result.String(),
				"tier", t,
			)

			insertStmt := `
		INSERT INTO time_series_data(task, value, date, tier)
		VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, t).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil
	case tasks.TransitionProvedByTierPerDay:
		var tiers []uint16 = make([]uint16, 0)

		query := "SELECT DISTINCT tier FROM events WHERE event = ? AND tier IS NOT NULL;"

		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionProved).
			Scan(&tiers).Error
		if err != nil {
			return err
		}

		slog.Info("tiers", "tiers", tiers)

		for _, tier := range tiers {
			t := tier

			var dailyCountByTier decimal.NullDecimal

			// nolint: lll
			query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND tier = ?"
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameTransitionProved, dateString, t).
				Scan(&dailyCountByTier).Error

			if err != nil {
				return err
			}

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", dailyCountByTier.Decimal.String(),
				"tier", t,
			)

			insertStmt := `
		INSERT INTO time_series_data(task, value, date, tier)
		VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, t).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil
	case tasks.TransitionContestedByTierPerDay:
		var tiers []uint16 = make([]uint16, 0)

		query := "SELECT DISTINCT tier FROM events WHERE event = ? AND tier IS NOT NULL;"

		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionContested).
			Scan(&tiers).Error
		if err != nil {
			return err
		}

		slog.Info("tiers", "tiers", tiers)

		for _, tier := range tiers {
			t := tier

			var dailyCountByTier decimal.NullDecimal

			// nolint: lll
			query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND tier = ?"
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameTransitionContested, dateString, t).
				Scan(&dailyCountByTier).Error

			if err != nil {
				return err
			}

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", dailyCountByTier.Decimal.String(),
				"tier", t,
			)

			insertStmt := `
		INSERT INTO time_series_data(task, value, date, tier)
		VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, t).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil
	case tasks.TotalTransitionContestedByTier:
		var tiers []uint16 = make([]uint16, 0)

		query := "SELECT DISTINCT tier FROM events WHERE event = ? AND tier IS NOT NULL;"

		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionContested).
			Scan(&tiers).Error
		if err != nil {
			return err
		}

		slog.Info("tiers", "tiers", tiers)

		for _, tier := range tiers {
			t := tier

			var dailyCountByTier decimal.NullDecimal

			// nolint: lll
			query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND tier = ?"
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameTransitionContested, dateString, t).
				Scan(&dailyCountByTier).Error

			if err != nil {
				return err
			}

			tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, &t)
			if err != nil {
				return err
			}

			result := tsdResult.Decimal.Add(dailyCountByTier.Decimal)

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", result.String(),
				"tier", t,
			)

			insertStmt := `
		INSERT INTO time_series_data(task, value, date, tier)
		VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, t).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil
	case tasks.TotalProofRewards:
		var feeTokenAddresses []string = make([]string, 0)
		// get unique fee token addresses
		query := "SELECT DISTINCT(fee_token_address) FROM stats WHERE stat_type = ?"

		err = g.db.GormDB().
			Raw(query, eventindexer.StatTypeProofReward).
			Scan(&feeTokenAddresses).Error
		if err != nil {
			return err
		}

		slog.Info("feeTokenAddresses", "addresses", feeTokenAddresses)

		for _, feeTokenAddress := range feeTokenAddresses {
			f := feeTokenAddress

			var dailyProofRewards decimal.NullDecimal

			// nolint: lll
			query := "SELECT COALESCE(SUM(proof_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND fee_token_address = ?"
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameBlockAssigned, dateString, f).
				Scan(&dailyProofRewards).Error

			if err != nil {
				return err
			}

			tsdResult, err := g.previousDayTsdResultByTask(task, date, &f, nil)
			if err != nil {
				return err
			}

			result := tsdResult.Decimal.Add(dailyProofRewards.Decimal)

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", result.String(),
				"feeTokenAddress", f,
			)

			insertStmt := `
		INSERT INTO time_series_data(task, value, date, fee_token_address)
		VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, f).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil
	case tasks.ProofRewardsPerDay:
		var feeTokenAddresses []string = make([]string, 0)
		// get unique fee token addresses
		query := "SELECT DISTINCT(fee_token_address) FROM stats WHERE stat_type = ?"

		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameBlockAssigned).
			Scan(&feeTokenAddresses).Error
		if err != nil {
			return err
		}

		for _, feeTokenAddress := range feeTokenAddresses {
			f := feeTokenAddress

			var result decimal.Decimal

			// nolint: lll
			query := `SELECT COALESCE(SUM(proof_reward), 0) FROM events WHERE event = ? AND DATE(transacted_at) = ? AND fee_token_address = ?`
			err = g.db.GormDB().
				Raw(query, eventindexer.EventNameBlockAssigned, dateString, f).
				Scan(&result).Error

			if err != nil {
				return err
			}

			slog.Info("Query successful",
				"task", task,
				"date", dateString,
				"result", result.String(),
				"feeTokenAddress", f,
			)

			insertStmt := `
			INSERT INTO time_series_data(task, value, date, fee_token_address)
			VALUES (?, ?, ?, ?)`

			err = g.db.GormDB().Exec(insertStmt, task, result, dateString, f).Error
			if err != nil {
				slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
				return err
			}
		}

		// return early for array processing data
		return nil

	case tasks.BridgeMessagesSentPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &result)
	case tasks.TotalBridgeMessagesSent:
		var dailyMsgSentCount decimal.NullDecimal

		err = g.eventCount(task, date, eventindexer.EventNameMessageSent, &dailyMsgSentCount)
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
		}

		result = tsdResult.Decimal.Add(dailyMsgSentCount.Decimal)
	case tasks.ProposeBlockTxPerDay:
		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &result)
	case tasks.TotalProposeBlockTx:
		var dailyProposerCount decimal.NullDecimal

		err = g.eventCount(task, date, eventindexer.EventNameBlockProposed, &dailyProposerCount)
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
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
			return err
		}
	case tasks.UniqueProversPerDay:
		query := "SELECT COUNT(DISTINCT address) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionProved, dateString).
			Scan(&result).Error
	case tasks.TotalUniqueProvers:
		query := `SELECT COUNT(DISTINCT address) FROM events WHERE event = ?`

		err = g.db.GormDB().Raw(
			query,
			eventindexer.EventNameTransitionProved,
		).Scan(&result).Error
		if err != nil {
			return err
		}
	case tasks.TransitionProvedTxPerDay:
		query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionProved, dateString).
			Scan(&result).Error
	case tasks.TotalTransitionProvedTx:
		var dailyTransitionProvedCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(
			query,
			eventindexer.EventNameTransitionProved,
			dateString,
		).Scan(&dailyTransitionProvedCount).Error
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
		}

		result = tsdResult.Decimal.Add(dailyTransitionProvedCount.Decimal)
	case tasks.TransitionContestedTxPerDay:
		query := "SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?"
		err = g.db.GormDB().
			Raw(query, eventindexer.EventNameTransitionContested, dateString).
			Scan(&result).Error
	case tasks.TotalTransitionContestedTx:
		var dailyTransitionContestedCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM events WHERE event = ? AND DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(
			query,
			eventindexer.EventNameTransitionContested,
			dateString,
		).Scan(&dailyTransitionContestedCount).Error
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
		}

		result = tsdResult.Decimal.Add(dailyTransitionContestedCount.Decimal)
	case tasks.AccountsPerDay:
		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalAccounts:
		var dailyAccountsCount decimal.NullDecimal

		query := `SELECT COUNT(*) FROM accounts WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyAccountsCount).Error
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
		}

		result = tsdResult.Decimal.Add(dailyAccountsCount.Decimal)
	case tasks.TransactionsPerDay:
		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`
		err = g.db.GormDB().Raw(query, dateString).Scan(&result).Error
	case tasks.TotalTransactions:
		var dailyTxCount decimal.NullDecimal

		// get current days txs, get previous entry for the time series data, add them together.

		query := `SELECT COUNT(*) FROM transactions WHERE DATE(transacted_at) = ?`

		err = g.db.GormDB().Raw(query, dateString).Scan(&dailyTxCount).Error
		if err != nil {
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
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
			return err
		}

		tsdResult, err := g.previousDayTsdResultByTask(task, date, nil, nil)
		if err != nil {
			return err
		}

		result = tsdResult.Decimal.Add(dailyContractCount.Decimal)
	default:
		return errors.New("task not supported")
	}

	if err != nil {
		return err
	}

	slog.Info("Query successful", "task", task, "date", dateString, "result", result.String())

	insertStmt := `
		INSERT INTO time_series_data(task, value, date)
		VALUES (?, ?, ?)`

	err = g.db.GormDB().Exec(insertStmt, task, result, dateString).Error
	if err != nil {
		slog.Info("Insert failed", "task", task, "date", dateString, "error", err.Error())
		return err
	}

	return nil
}

// previousDayTsdResultByTask returns the previous day's time series data, based on
// task and time passed in.
func (g *Generator) previousDayTsdResultByTask(
	task string,
	date time.Time,
	feeTokenAddress *string,
	tier *uint16,
) (decimal.NullDecimal, error) {
	var tsdResult decimal.NullDecimal

	var tsdQuery string = `SELECT value FROM time_series_data WHERE task = ? AND date = ?`

	var q *gorm.DB = g.db.GormDB().
		Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02"))

	if feeTokenAddress != nil {
		tsdQuery = `SELECT value FROM time_series_data WHERE task = ? AND date = ? AND fee_token_address = ?`
		q = g.db.GormDB().
			Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02"), *feeTokenAddress)
	}

	if tier != nil {
		tsdQuery = `SELECT value FROM time_series_data WHERE task = ? AND date = ? AND tier = ?`
		q = g.db.GormDB().
			Raw(tsdQuery, task, date.AddDate(0, 0, -1).Format("2006-01-02"), *tier)
	}

	err := q.
		Scan(&tsdResult).Error
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
