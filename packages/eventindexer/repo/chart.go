package repo

import (
	"context"

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

	var q string = `SELECT * FROM time_series_data
	WHERE task = ? AND date BETWEEN ? AND ?
	ORDER BY date;`

	tx = r.getDB().Raw(q, task, start, end)

	if feeTokenAddress != "" {
		q = `SELECT * FROM time_series_data
		WHERE task = ? AND date BETWEEN ? AND ?
		AND fee_token_address = ?
		ORDER BY date;`

		tx = r.getDB().Raw(q, task, start, end, feeTokenAddress)
	} else if tier != "" {
		q = `SELECT * FROM time_series_data
		WHERE task = ? AND date BETWEEN ? AND ?
		AND tier = ?
		ORDER BY date;`

		tx = r.getDB().Raw(q, task, start, end, tier)
	}

	var tsd []*eventindexer.TimeSeriesData

	if err := tx.Scan(&tsd).Error; err != nil {
		return nil, err
	}

	chart := &eventindexer.ChartResponse{
		Chart: make([]eventindexer.ChartItem, 0),
	}

	for _, d := range tsd {
		chart.Chart = append(chart.Chart, eventindexer.ChartItem{
			Date:  d.Date,
			Value: d.Value.Decimal.String(),
		})
	}

	return chart, nil
}
