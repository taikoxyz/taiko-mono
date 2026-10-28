package repo

import (
	"context"

	"gorm.io/gorm"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

const NFTCheckpointEvent = "NFTIndexerCheckpoint"

// NFTCursorRepository maintains one checkpoint per chain under the writer lock.
type NFTCursorRepository struct{ db db.DB }

func NewNFTCursorRepository(database db.DB) (*NFTCursorRepository, error) {
	if database == nil {
		return nil, db.ErrNoDB
	}

	return &NFTCursorRepository{db: database}, nil
}

func (r *NFTCursorRepository) FindLatestBlockID(ctx context.Context, chainID uint64) (uint64, error) {
	var latest uint64

	err := r.db.GormDB().WithContext(ctx).Raw(
		"SELECT COALESCE(MAX(emitted_block_id), 0) FROM events WHERE chain_id = ? AND event <> ?", chainID, NFTCheckpointEvent).Scan(&latest).Error
	if err != nil {
		return 0, errors.Wrap(err, "read legacy NFT startup cursor")
	}

	return latest, nil
}

// FindCheckpoint distinguishes a completed block zero from an absent checkpoint.
func (r *NFTCursorRepository) FindCheckpoint(ctx context.Context, chainID uint64) (uint64, bool, error) {
	var row struct {
		ID             uint64
		EmittedBlockID uint64
	}

	result := r.db.GormDB().WithContext(ctx).Table("events").Select("id, emitted_block_id").
		Where("chain_id = ? AND event = ?", chainID, NFTCheckpointEvent).Limit(1).Find(&row)

	return row.EmittedBlockID, result.RowsAffected > 0, errors.Wrap(result.Error, "read NFT checkpoint")
}

// SaveCheckpoint runs on the reserved writer session. The chain writer lock
// serializes the initial insert; subsequent writes monotonically update that row.
func (r *NFTCursorRepository) SaveCheckpoint(ctx context.Context, chainID, height uint64) error {
	return r.db.GormDB().WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var id uint64

		// The named per-chain writer lock serializes this lookup and insert.
		// A locking missing-row read would gap-lock other chains in MySQL.
		// The primary-key UPDATE below takes its own row lock.
		result := tx.Raw("SELECT id FROM events WHERE chain_id = ? AND event = ? LIMIT 1", chainID, NFTCheckpointEvent).Scan(&id)
		if result.Error != nil {
			return errors.Wrap(result.Error, "find NFT checkpoint")
		}

		if result.RowsAffected == 0 {
			return tx.Exec("INSERT INTO events (name, event, chain_id, data, emitted_block_id, transacted_at) VALUES (?, ?, ?, '{}', ?, NOW())",
				NFTCheckpointEvent, NFTCheckpointEvent, chainID, height).Error
		}

		return tx.Exec("UPDATE events SET emitted_block_id = GREATEST(emitted_block_id, ?), transacted_at = NOW() WHERE id = ?", height, id).Error
	})
}
