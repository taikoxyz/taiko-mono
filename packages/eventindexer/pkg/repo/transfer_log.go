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
// processed_transfer_logs does the work: INSERT IGNORE drops the duplicate and
// reports no affected rows.
//
// The modifier is deliberate. clause.OnConflict{DoNothing: true} looks
// equivalent, but gorm's MySQL dialector rewrites it to
// ON DUPLICATE KEY UPDATE id=id, whose affected-row count is 0 only while the
// connection lacks CLIENT_FOUND_ROWS; with clientFoundRows=true in the DSN that
// no-op update reports one row, every replay reads as new, and the balance
// mutation is applied twice. Replay correctness must not hinge on a driver flag.
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

	res := tx.WithContext(ctx).Clauses(clause.Insert{Modifier: "IGNORE"}).Create(p)
	if res.Error != nil {
		return false, errors.Wrap(res.Error, "tx.Create")
	}

	return res.RowsAffected == 1, nil
}
