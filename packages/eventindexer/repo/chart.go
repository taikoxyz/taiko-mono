package repo

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
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
) (*eventindexer.ChartResponse, error) {
	q := `SELECT * FROM time_series_data
	WHERE task = ? AND date BETWEEN ? AND ?
	ORDER BY date;`

	var tsd []*eventindexer.TimeSeriesData

	if err := r.getDB().Raw(q, task, start, end).Scan(&tsd).Error; err != nil {
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
