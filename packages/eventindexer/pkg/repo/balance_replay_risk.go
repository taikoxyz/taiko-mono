package repo

import (
	"context"
	"database/sql"

	"github.com/pkg/errors"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

// UnclaimedBalanceReplayRisk reports whether a previous process may already have
// applied balance mutations for the block range this process is about to replay,
// without leaving claims behind in processed_transfer_logs.
//
// The claim table makes replays idempotent, but only for logs claimed at least
// once. On the first start after the table is introduced there are no claims,
// while setInitialIndexingBlockByMode still rewinds the cursor into a range the
// previous process already applied — so that one restart would double count.
// Nothing records what the previous process applied, so this cannot be repaired
// automatically; the point of this check is to make the situation loud.
//
// The signal is recency, not mere existence. Balances written at or after the
// block being resumed from mean a process was applying them inside the range
// about to be replayed. Balances that predate it — a chain where balance
// indexing was switched off long ago and is only now being re-enabled — cannot
// be double counted, because the replay range is entirely newer than anything
// the previous process wrote.
func UnclaimedBalanceReplayRisk(
	ctx context.Context,
	d db.DB,
	chainID int64,
	kind string,
) (bool, error) {
	var table string

	switch kind {
	case eventindexer.TransferKindNFT:
		table = "nft_balances"
	case eventindexer.TransferKindERC20:
		table = "erc20_balances"
	default:
		return false, errors.Errorf("unknown transfer log kind %q", kind)
	}

	var claims int64

	if err := d.GormDB().WithContext(ctx).
		Table("processed_transfer_logs").
		Where("chain_id = ?", chainID).
		Where("kind = ?", kind).
		Count(&claims).Error; err != nil {
		return false, errors.Wrap(err, "count processed_transfer_logs")
	}

	// once this chain has claimed anything, every later replay is covered
	if claims > 0 {
		return false, nil
	}

	var lastBalanceWrite sql.NullTime

	if err := d.GormDB().WithContext(ctx).
		Table(table).
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
		Where("chain_id = ?", chainID).
		Select("transacted_at").
		Order("emitted_block_id DESC").
		Limit(1).
		Scan(&resumeBlockTime).Error; err != nil {
		return false, errors.Wrap(err, "resume block transacted_at")
	}

	// no events, so the cursor starts at the fork height rather than resuming
	// into a range a previous process worked on
	if !resumeBlockTime.Valid {
		return false, nil
	}

	return !lastBalanceWrite.Time.Before(resumeBlockTime.Time), nil
}
