package eventindexer

import (
	"time"

	"github.com/shopspring/decimal"
)

type TimeSeriesData struct {
	ID        int
	Task      string
	Value     decimal.NullDecimal
	Date      string
	CreatedAt time.Time
	UpdatedAt time.Time
}
