package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"gorm.io/gorm"
)

type StatRepository struct {
	db DB
}

func NewStatRepository(db DB) (*StatRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &StatRepository{
		db: db,
	}, nil
}

func (r *StatRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("stats")
}

func (r *StatRepository) Get(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery())

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.Stat{})

	return page, nil
}

func (r *StatRepository) GetByGuardianProverID(
	ctx context.Context,
	req *http.Request,
	id int,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery().Order("created_at desc").
		Where("guardian_prover_id = ?", id))

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.Stat{})

	return page, nil
}
