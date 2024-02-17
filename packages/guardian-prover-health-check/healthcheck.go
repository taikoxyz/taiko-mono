package guardianproverhealthcheck

import (
	"context"
	"net/http"
	"time"

	"github.com/morkid/paginate"
)

type HealthCheck struct {
	ID               int       `json:"id"`
	GuardianProverID uint64    `json:"guardianProverId"`
	Alive            bool      `json:"alive"`
	ExpectedAddress  string    `json:"expectedAddress"`
	RecoveredAddress string    `json:"recoveredAddress"`
	SignedResponse   string    `json:"signedResponse"`
	LatestL1Block    uint64    `json:"latestL1Block"`
	LatestL2Block    uint64    `json:"latestL2Block"`
	CreatedAt        time.Time `json:"createdAt"`
}

type SaveHealthCheckOpts struct {
	GuardianProverID uint64
	Alive            bool
	ExpectedAddress  string
	RecoveredAddress string
	SignedResponse   string
	LatestL1Block    uint64
	LatestL2Block    uint64
}

type HealthCheckRepository interface {
	Get(
		ctx context.Context,
		req *http.Request,
	) (paginate.Page, error)
	GetByGuardianProverID(
		ctx context.Context,
		req *http.Request,
		id int,
	) (paginate.Page, error)
	GetMostRecentByGuardianProverID(
		ctx context.Context,
		req *http.Request,
		id int,
	) (*HealthCheck, error)
	Save(opts SaveHealthCheckOpts) error
	GetUptimeByGuardianProverID(ctx context.Context, id int) (float64, int, error)
}
