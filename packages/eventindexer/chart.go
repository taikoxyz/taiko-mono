package eventindexer

type ChartResponse struct {
	Chart []ChartItem `json:"chart"`
}

type ChartItem struct {
	Date  string `json:"date"`
	Value string `json:"value"`
}
