package repo

import (
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

func (r *HealthCheckRepository) Save(opts guardianproverhealthcheck.SaveHealthCheckOpts) error {
	b := &guardianproverhealthcheck.HealthCheck{
		GuardianProverID: opts.GuardianProverID,
		Alive:            opts.Alive,
		ExpectedAddress:  opts.ExpectedAddress,
		RecoveredAddress: opts.RecoveredAddress,
		SignedResponse:   opts.SignedResponse,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}
