package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"gorm.io/gorm"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
)

type StartupRepository struct {
	db db.DB
}

func NewStartupRepository(dbHandler db.DB) (*StartupRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &StartupRepository{
		db: dbHandler,
	}, nil
}

func (r *StartupRepository) startQuery(ctx context.Context) *gorm.DB {
	return r.db.GormDB().WithContext(ctx).Table("startups")
}

func (r *StartupRepository) GetByGuardianProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	reqCtx := pg.With(r.startQuery(ctx).Order("created_at desc").
		Where("guardian_prover_address = ?", address))

	page := reqCtx.Request(req).Response(&[]guardianproverhealthcheck.Startup{})

	return page, nil
}

func (r *StartupRepository) GetMostRecentByGuardianProverAddress(
	ctx context.Context,
	address string,
) (*guardianproverhealthcheck.Startup, error) {
	s := &guardianproverhealthcheck.Startup{}

	if err := r.startQuery(ctx).Order("created_at desc").
		Where("guardian_prover_address = ?", address).Limit(1).
		Scan(s).Error; err != nil {
		return nil, err
	}

	return s, nil
}

func (r *StartupRepository) Save(ctx context.Context, opts *guardianproverhealthcheck.SaveStartupOpts) error {
	b := &guardianproverhealthcheck.Startup{
		GuardianProverAddress: opts.GuardianProverAddress,
		GuardianProverID:      opts.GuardianProverID,
		Revision:              opts.Revision,
		GuardianVersion:       opts.GuardianVersion,
		L1NodeVersion:         opts.L1NodeVersion,
		L2NodeVersion:         opts.L2NodeVersion,
	}
	if err := r.startQuery(ctx).Create(b).Error; err != nil {
		return err
	}

	return nil
}
