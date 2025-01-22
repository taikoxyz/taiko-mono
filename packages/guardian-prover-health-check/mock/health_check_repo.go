package mock

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type HealthCheckRepo struct {
	healthChecks []*guardianproverhealthcheck.HealthCheck
}

func NewHealthCheckRepository() *HealthCheckRepo {
	return &HealthCheckRepo{
		healthChecks: make([]*guardianproverhealthcheck.HealthCheck, 0),
	}
}
func (h *HealthCheckRepo) GetByGuardianProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (paginate.Page, error) {
	return paginate.Page{
		Items: h.healthChecks,
	}, nil
}

func (r *HealthCheckRepo) GetMostRecentByGuardianProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (*guardianproverhealthcheck.HealthCheck, error) {
	return &guardianproverhealthcheck.HealthCheck{}, nil
}

func (h *HealthCheckRepo) Get(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	return paginate.Page{
		Items: h.healthChecks,
	}, nil
}

func (h *HealthCheckRepo) Save(ctx context.Context, opts *guardianproverhealthcheck.SaveHealthCheckOpts) error {
	h.healthChecks = append(h.healthChecks, &guardianproverhealthcheck.HealthCheck{
		GuardianProverID: opts.GuardianProverID,
		Alive:            opts.Alive,
		ExpectedAddress:  opts.ExpectedAddress,
		RecoveredAddress: opts.RecoveredAddress,
		SignedResponse:   opts.SignedResponse,
		LatestL1Block:    opts.LatestL1Block,
		LatestL2Block:    opts.LatestL2Block,
	},
	)

	return nil
}

func (h *HealthCheckRepo) GetUptimeByGuardianProverAddress(
	ctx context.Context,
	address string,
) (float64, int, error) {
	return 25.5, 10, nil
}
