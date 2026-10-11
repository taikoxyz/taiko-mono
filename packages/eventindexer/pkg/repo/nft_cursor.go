package repo

import (
	"context"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

// NFTCursorRepository reads the historical event watermark for NFT startup.
// Migration history and this read-only compatibility path remain; events are
// no longer indexed or exposed by the NFT-only service.
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
		"SELECT COALESCE(MAX(emitted_block_id), 0) FROM events WHERE chain_id = ?", chainID).Scan(&latest).Error
	if err != nil {
		return 0, errors.Wrap(err, "read legacy NFT startup cursor")
	}

	return latest, nil
}
