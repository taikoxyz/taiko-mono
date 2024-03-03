package repo

import (
	"context"
	"fmt"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"golang.org/x/exp/slog"
	"gorm.io/gorm"
)

type ChartRepository struct {
	db eventindexer.DB
}

func NewChartRepository(db eventindexer.DB) (*ChartRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &ChartRepository{
		db: db,
	}, nil
}

func (r *ChartRepository) getDB() *gorm.DB {
	return r.db.GormDB().Table("time_series_data")
}

func (r *ChartRepository) Find(
	ctx context.Context,
	task string,
	start string,
	end string,
	feeTokenAddress string,
	tier string,
) (*eventindexer.ChartResponse, error) {
	slog.Info("finding chart", "task", task, "tier", tier, "feeTokenAddress", feeTokenAddress)

	var tx *gorm.DB

	var startDate time.Time
	var endDate time.Time
	var err error
	if start != "" {
		startDate, err = time.Parse("2006-01-02", start)
		if err != nil {
			fmt.Print(err)
			return nil, err
		}
	}
	if end != "" {
		endDate, err = time.Parse("2006-01-02", end)
		if err != nil {
			return nil, err
		}
	}

	var q string
	var args []interface{}
	args = append(args, task)
	if start != "" && end != "" {
		q = `SELECT * FROM time_series_data
         WHERE task = ? AND STR_TO_DATE(date, '%Y-%m-%d') BETWEEN ? AND ?
         ORDER BY STR_TO_DATE(date, '%Y-%m-%d')`
		args = append(args, startDate, endDate)
	} else {
		q = `SELECT * FROM time_series_data
         WHERE task = ?
         ORDER BY date`
	}

	if feeTokenAddress != "" {
		q += ` AND fee_token_address = ?`
		args = append(args, feeTokenAddress)
	} else if tier != "" {
		q += ` AND tier = ?`
		args = append(args, tier)
	}

	tx = r.getDB().Raw(q, args...)

	var tsd []*eventindexer.TimeSeriesData
	if err := tx.Scan(&tsd).Error; err != nil {
		return nil, err
	}

	chart := &eventindexer.ChartResponse{
		Chart: make([]eventindexer.ChartItem, len(tsd)),
	}
	for i, d := range tsd {
		chart.Chart[i] = eventindexer.ChartItem{
			Date:  d.Date,
			Value: d.Value.Decimal.String(),
		}
	}

	return chart, nil
}
