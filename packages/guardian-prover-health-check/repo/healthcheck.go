package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"gorm.io/gorm"
)

type HealthCheckRepository struct {
	db DB
}

func NewHealthCheckRepository(db DB) (*HealthCheckRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &HealthCheckRepository{
		db: db,
	}, nil
}

func (r *HealthCheckRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("health_checks")
}

func (r *HealthCheckRepository) Get(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery())

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.HealthCheck{})

	return page, nil
}

func (r *HealthCheckRepository) GetByGuardianProverID(
	ctx context.Context,
	req *http.Request,
	id int,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery().Where("guardian_prover_id = ?", id))

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.HealthCheck{})

	return page, nil
}

func (r *HealthCheckRepository) Save(opts guardianproverhealthcheck.SaveHealthCheckOpts) error {
	b := &guardianproverhealthcheck.HealthCheck{
		Alive:            opts.Alive,
		ExpectedAddress:  opts.ExpectedAddress,
		RecoveredAddress: opts.RecoveredAddress,
		SignedResponse:   opts.SignedResponse,
		GuardianProverID: opts.GuardianProverID,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}
