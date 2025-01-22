package repo

import (
	"context"
	"gorm.io/gorm"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
)

type SignedBlockRepository struct {
	db db.DB
}

func NewSignedBlockRepository(dbHandler db.DB) (*SignedBlockRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &SignedBlockRepository{
		db: dbHandler,
	}, nil
}

func (r *SignedBlockRepository) startQuery(ctx context.Context) *gorm.DB {
	return r.db.GormDB().WithContext(ctx).Table("signed_blocks")
}

func (r *SignedBlockRepository) Save(ctx context.Context, opts *guardianproverhealthcheck.SaveSignedBlockOpts) error {
	b := &guardianproverhealthcheck.SignedBlock{
		GuardianProverID: opts.GuardianProverID,
		BlockID:          opts.BlockID,
		BlockHash:        opts.BlockHash,
		RecoveredAddress: opts.RecoveredAddress,
		Signature:        opts.Signature,
	}
	if err := r.startQuery(ctx).Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *SignedBlockRepository) GetByStartingBlockID(
	ctx context.Context,
	opts guardianproverhealthcheck.GetSignedBlocksByStartingBlockIDOpts,
) ([]*guardianproverhealthcheck.SignedBlock, error) {
	var sb []*guardianproverhealthcheck.SignedBlock

	if err := r.startQuery(ctx).Where("block_id >= ?", opts.StartingBlockID).Find(&sb).Error; err != nil {
		return nil, err
	}

	return sb, nil
}

func (r *SignedBlockRepository) GetMostRecentByGuardianProverAddress(ctx context.Context, address string) (
	*guardianproverhealthcheck.SignedBlock,
	error) {
	q := `SELECT *
	FROM signed_blocks
	WHERE block_id = (
		SELECT MAX(block_id)
		FROM signed_blocks
		WHERE recovered_address = ?
	) AND recovered_address = ?;`

	var b *guardianproverhealthcheck.SignedBlock

	if err := r.startQuery(ctx).Raw(q, address, address).Scan(&b).Error; err != nil {
		return nil, err
	}

	return b, nil
}
