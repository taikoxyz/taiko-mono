package guardianproverhealthcheck

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

type HealthCheck struct {
	ID               int
	GuardianProverID uint64
	Alive            bool
	ExpectedAddress  string
	RecoveredAddress string
	SignedResponse   string
}

type SaveHealthCheckOpts struct {
	GuardianProverID uint64
	Alive            bool
	ExpectedAddress  string
	RecoveredAddress string
	SignedResponse   string
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
	Save(opts SaveHealthCheckOpts) error
}
