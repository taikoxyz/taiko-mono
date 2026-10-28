package repo

import (
	"context"
	"database/sql"

	"github.com/pkg/errors"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

// UnclaimedNFTReplayRisk checks the legacy bootstrap overlap when no durable
// NFT checkpoint exists. Balances without a positive legacy watermark are at
// risk even if some transfer claims exist: partial claims cannot cover genesis
// replay. With a usable watermark, preserve the established recency check for
// the first pre-claim restart. NFT markers never participate in that comparison.
func UnclaimedNFTReplayRisk(
	ctx context.Context,
	d db.DB,
	chainID int64,
) (bool, error) {
	var claims int64

	if err := d.GormDB().WithContext(ctx).
		Table("processed_transfer_logs").
		Where("chain_id = ?", chainID).
		Where("kind = ?", eventindexer.TransferKindNFT).
		Count(&claims).Error; err != nil {
		return false, errors.Wrap(err, "count processed_transfer_logs")
	}

	var lastBalanceWrite sql.NullTime

	if err := d.GormDB().WithContext(ctx).
		Table("nft_balances").
		Where("chain_id = ?", chainID).
		Select("MAX(updated_at)").
		Scan(&lastBalanceWrite).Error; err != nil {
		return false, errors.Wrap(err, "max balance updated_at")
	}

	// no balances for this chain, so there is nothing to double count
	if !lastBalanceWrite.Valid {
		return false, nil
	}

	var resumeBlockTime sql.NullTime

	if err := d.GormDB().WithContext(ctx).
		Table("events").
		Where("chain_id = ? AND event <> ? AND emitted_block_id > 0", chainID, NFTCheckpointEvent).
		Select("transacted_at").
		Order("emitted_block_id DESC").
		Limit(1).
		Scan(&resumeBlockTime).Error; err != nil {
		return false, errors.Wrap(err, "resume block transacted_at")
	}

	// Missing history cannot prove that some claims cover existing balances.
	if !resumeBlockTime.Valid {
		return true, nil
	}

	if claims > 0 {
		return false, nil
	}

	return !lastBalanceWrite.Time.Before(resumeBlockTime.Time), nil
}

// NFTReplayState reports retained indexing state before accepting a clean rebuild.
func NFTReplayState(ctx context.Context, d db.DB, chainID uint64) (balances, claims, checkpoints, legacy int64, err error) {
	for _, query := range []struct {
		table, predicate string
		args             []interface{}
		count            *int64
	}{
		{"processed_transfer_logs", "chain_id = ? AND kind = ?", []interface{}{chainID, eventindexer.TransferKindNFT}, &claims},
		{"nft_balances", "chain_id = ?", []interface{}{chainID}, &balances},
		{"events", "chain_id = ? AND event = ?", []interface{}{chainID, NFTCheckpointEvent}, &checkpoints},
		{"events", "chain_id = ? AND event <> ? AND emitted_block_id > 0", []interface{}{chainID, NFTCheckpointEvent}, &legacy},
	} {
		if err = d.GormDB().WithContext(ctx).Table(query.table).Where(query.predicate, query.args...).Count(query.count).Error; err != nil {
			err = errors.Wrap(err, "count "+query.table)
			return
		}
	}

	return
}
