package mock

import (
	"context"
	"errors"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type StartupRepo struct {
	startups []*guardianproverhealthcheck.Startup
}

func NewStartupRepository() *StartupRepo {
	return &StartupRepo{
		startups: make([]*guardianproverhealthcheck.Startup, 0),
	}
}
func (h *StartupRepo) GetByGuardianProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (paginate.Page, error) {
	return paginate.Page{
		Items: h.startups,
	}, nil
}

func (r *StartupRepo) GetMostRecentByGuardianProverAddress(
	ctx context.Context,
	address string,
) (*guardianproverhealthcheck.Startup, error) {
	var s *guardianproverhealthcheck.Startup

	for k, v := range r.startups {
		if v.GuardianProverAddress == address {
			if k == 0 {
				s = v
			} else if v.CreatedAt.Compare(s.CreatedAt) == 1 {
				s = v
			}
		}
	}

	if s == nil {
		return nil, errors.New("no signed blocks by this guardian prover")
	}

	return s, nil
}

func (h *StartupRepo) Save(ctx context.Context, opts *guardianproverhealthcheck.SaveStartupOpts) error {
	h.startups = append(h.startups, &guardianproverhealthcheck.Startup{
		GuardianProverID:      opts.GuardianProverID,
		GuardianProverAddress: opts.GuardianProverAddress,
		Revision:              opts.Revision,
		GuardianVersion:       opts.GuardianVersion,
		L1NodeVersion:         opts.L1NodeVersion,
		L2NodeVersion:         opts.L2NodeVersion,
	},
	)

	return nil
}
