package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"gorm.io/gorm"
)

type StartupRepository struct {
	db DB
}

func NewStartupRepository(db DB) (*StartupRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &StartupRepository{
		db: db,
	}, nil
}

func (r *StartupRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("startups")
}

func (r *StartupRepository) GetByGuardianProverID(
	ctx context.Context,
	req *http.Request,
	id int,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery().Order("created_at desc").
		Where("guardian_prover_id = ?", id))

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.Startup{})

	return page, nil
}

func (r *StartupRepository) GetMostRecentByGuardianProverID(
	ctx context.Context,
	id int,
) (*guardianproverhealthcheck.Startup, error) {
	s := &guardianproverhealthcheck.Startup{}

	if err := r.startQuery().Order("created_at desc").
		Where("guardian_prover_id = ?", id).Limit(1).
		Scan(s).Error; err != nil {
		return nil, err
	}

	return s, nil
}

func (r *StartupRepository) Save(opts guardianproverhealthcheck.SaveStartupOpts) error {
	b := &guardianproverhealthcheck.Startup{
		GuardianProverAddress: opts.GuardianProverAddress,
		GuardianProverID:      opts.GuardianProverID,
		Revision:              opts.Revision,
		GuardianVersion:       opts.GuardianVersion,
		L1NodeVersion:         opts.L1NodeVersion,
		L2NodeVersion:         opts.L2NodeVersion,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}
