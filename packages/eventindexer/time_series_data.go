package eventindexer

import "time"

type TimeSeriesData struct {
	ID        int
	Task      string
	Value     string
	Date      string
	CreatedAt time.Time
	UpdatedAt time.Time
}
