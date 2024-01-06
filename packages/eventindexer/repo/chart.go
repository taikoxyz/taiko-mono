package repo

import (
	"context"
	"fmt"

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
	feeTokenAddress string,
	tier string,
) (*eventindexer.ChartResponse, error) {
	var q string = `SELECT * FROM time_series_data
	WHERE task = ? AND date BETWEEN ? AND ?
	ORDER BY date;`

	if feeTokenAddress != "" {
		q = fmt.Sprintf(`SELECT * FROM time_series_data
		WHERE task = ? AND date BETWEEN ? AND ?
		AND fee_token_address = %v 
		ORDER BY date;`,
			feeTokenAddress,
		)
	} else if tier != "" {
		q = fmt.Sprintf(`SELECT * FROM time_series_data
		WHERE task = ? AND date BETWEEN ? AND ?
		AND tier = %v 
		ORDER BY date;`,
			tier,
		)
	}

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
