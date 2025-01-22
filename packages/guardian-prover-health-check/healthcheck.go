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
	GetByGuardianProverAddress(
		ctx context.Context,
		req *http.Request,
		address string,
	) (paginate.Page, error)
	GetMostRecentByGuardianProverAddress(
		ctx context.Context,
		req *http.Request,
		address string,
	) (*HealthCheck, error)
	Save(ctx context.Context, opts *SaveHealthCheckOpts) error
	GetUptimeByGuardianProverAddress(ctx context.Context, address string) (float64, int, error)
}
