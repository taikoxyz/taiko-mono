package http

type galaxeData struct {
	IsOK bool `json:"is_ok"`
}

type galaxeAPIResponse struct {
	Data galaxeData `json:"data"`
}
