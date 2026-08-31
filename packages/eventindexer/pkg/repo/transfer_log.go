package repo

import (
	"context"

	"github.com/pkg/errors"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// markTransferLogApplied claims a transfer log for application inside tx.
//
// It returns false when the log has already been applied, which is what turns a
// replayed block into a no-op instead of a double count. The unique key on
// processed_transfer_logs does the work: the insert is an INSERT IGNORE, so a
// second attempt affects no rows.
//
// It must be called inside the same transaction as the balance mutation, so that
// a rolled back mutation also releases the claim.
func markTransferLogApplied(
	ctx context.Context,
	tx *gorm.DB,
	ref eventindexer.TransferLogRef,
) (bool, error) {
	p := &eventindexer.ProcessedTransferLog{
		ChainID:    ref.ChainID,
		TxHash:     ref.TxHash,
		LogIndex:   ref.LogIndex,
		BatchIndex: ref.BatchIndex,
		Kind:       ref.Kind,
	}

	res := tx.WithContext(ctx).Clauses(clause.OnConflict{DoNothing: true}).Create(p)
	if res.Error != nil {
		return false, errors.Wrap(res.Error, "tx.Create")
	}

	return res.RowsAffected == 1, nil
}
