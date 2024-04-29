package repo

import (
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"gorm.io/gorm"
)

type SignedBlockRepository struct {
	db DB
}

func NewSignedBlockRepository(db DB) (*SignedBlockRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &SignedBlockRepository{
		db: db,
	}, nil
}

func (r *SignedBlockRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("signed_blocks")
}

func (r *SignedBlockRepository) Save(opts guardianproverhealthcheck.SaveSignedBlockOpts) error {
	b := &guardianproverhealthcheck.SignedBlock{
		GuardianProverID: opts.GuardianProverID,
		BlockID:          opts.BlockID,
		BlockHash:        opts.BlockHash,
		RecoveredAddress: opts.RecoveredAddress,
		Signature:        opts.Signature,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *SignedBlockRepository) GetByStartingBlockID(
	opts guardianproverhealthcheck.GetSignedBlocksByStartingBlockIDOpts,
) ([]*guardianproverhealthcheck.SignedBlock, error) {
	var sb []*guardianproverhealthcheck.SignedBlock

	if err := r.startQuery().Where("block_id >= ?", opts.StartingBlockID).Find(&sb).Error; err != nil {
		return nil, err
	}

	return sb, nil
}

func (r *SignedBlockRepository) GetMostRecentByGuardianProverAddress(address string) (
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

	if err := r.startQuery().Raw(q, address, address).Scan(&b).Error; err != nil {
		return nil, err
	}

	return b, nil
}
