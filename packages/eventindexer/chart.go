package eventindexer

import "context"

type ChartResponse struct {
	Chart []ChartItem `json:"chart"`
}

type ChartItem struct {
	Date  string `json:"date"`
	Value string `json:"value"`
}

type ChartRepository interface {
	Find(
		ctx context.Context,
		task string,
		start string,
		end string,
		feeTokenAddress string,
		tier string,
	) (*ChartResponse, error)
}
