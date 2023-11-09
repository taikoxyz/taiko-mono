package mock

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type StatRepo struct {
	stats []*guardianproverhealthcheck.Stat
}

func NewStatRepository() *StatRepo {
	return &StatRepo{
		stats: make([]*guardianproverhealthcheck.Stat, 0),
	}
}
func (s *StatRepo) GetByGuardianProverID(
	ctx context.Context,
	req *http.Request,
	id int,
) (paginate.Page, error) {
	return paginate.Page{
		Items: s.stats,
	}, nil
}

func (s *StatRepo) Get(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	return paginate.Page{
		Items: s.stats,
	}, nil
}
