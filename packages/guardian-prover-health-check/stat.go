package guardianproverhealthcheck

import (
	"context"
	"net/http"
	"time"

	"github.com/morkid/paginate"
)

type Stat struct {
	GuardianProverID   int       `json:"guardianProverId"`
	Date               string    `json:"date"`
	Requests           int       `json:"requests"`
	SuccessfulRequests int       `json:"successfulRequests"`
	Uptime             float64   `json:"uptime"`
	CreatedAt          time.Time `json:"created_at"`
}

type StatRepository interface {
	Get(
		ctx context.Context,
		req *http.Request,
	) (paginate.Page, error)
	GetByGuardianProverID(
		ctx context.Context,
		req *http.Request,
		id int,
	) (paginate.Page, error)
}
