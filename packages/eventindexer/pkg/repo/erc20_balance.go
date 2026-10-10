package repo

import (
	"context"
	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// balanceRaceAttempts bounds the retry loop in increaseBalanceInDB. One attempt
// is enough unless another transfer creates or deletes the same balance row
// concurrently, which is exactly what the unique key exists to expose.
const balanceRaceAttempts = 10

// balanceStep is what the next attempt in increaseBalanceInDB has to do.
//
// The probe step must not be repeated once the transaction has read anything.
// Under REPEATABLE READ its snapshot is fixed by the first read, so it keeps
// reporting whatever it saw then: an absence that a concurrent transfer has
// since filled, or a row that a concurrent transfer has since deleted. The two
// other steps exist to move past that without restarting the transaction, which
// has to stay open because the claim in processed_transfer_logs lives in it.
type balanceStep int

const (
	// probeBalance runs the non-locking existence check.
	probeBalance balanceStep = iota
	// readBalance goes straight to the locking read, because a row is known to
	// exist: the unique key has just refused an insert.
	readBalance
	// insertBalance goes straight to the insert, because the locking read has
	// just missed: a concurrent transfer drained the row and deleted it.
	insertBalance
)

type ERC20BalanceRepository struct {
	db db.DB
}

func NewERC20BalanceRepository(dbHandler db.DB) (*ERC20BalanceRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &ERC20BalanceRepository{
		db: dbHandler,
	}, nil
}

// erc20BalanceExists reports whether a balance row for opts is already there.
//
// It deliberately takes no lock. The probe only decides whether this call is
// going to insert or to update, and the update path re-reads the row under
// FOR UPDATE. Making the probe a locking read instead would take a gap lock on
// the balance index whenever the row is missing, and two transfers crediting an
// account for the first time would then each hold a gap lock the other's insert
// has to queue behind — an insert-intention deadlock in precisely the situation
// this code is meant to handle.
func erc20BalanceExists(db *gorm.DB, opts eventindexer.UpdateERC20BalanceOpts) (bool, error) {
	var count int64

	err := db.Model(&eventindexer.ERC20Balance{}).
		Where("contract_address = ?", opts.ContractAddress).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		Count(&count).
		Error
	if err != nil {
		return false, errors.Wrap(err, "r.db.Count")
	}

	return count > 0, nil
}

// findERC20BalanceForUpdate reads the balance row for opts and locks it until
// the transaction ends.
//
// The lock is what makes the read-modify-write in its callers correct. amount is a
// uint256 stored as VARCHAR(200), so MySQL cannot add to it in place and the
// arithmetic has to happen in Go; without a lock two transfers to the same
// account read the same old value and the second write erases the first. A
// locking read is also a current read, so it sees the value the previous writer
// committed rather than the snapshot this transaction started with.
func findERC20BalanceForUpdate(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, bool, error) {
	b := &eventindexer.ERC20Balance{}

	err := db.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("contract_address = ?", opts.ContractAddress).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		First(b).
		Error
	if err != nil {
		// allow to be not found, it may be the first time this user has this token
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, false, nil
		}

		return nil, false, errors.Wrap(err, "r.db.gormDB.First")
	}

	return b, true, nil
}

// isDuplicateEntry reports whether err is MySQL's ER_DUP_ENTRY, raised by the
// unique key on (contract_address, address, chain_id) when two transfers race to
// create the same balance row. The driver is only an indirect dependency, so the
// error is matched by message the same way the deadlock retry below matches
// "Deadlock".
func isDuplicateEntry(err error) bool {
	return err != nil && strings.Contains(err.Error(), "Duplicate entry")
}

// insertERC20Balance creates the first balance row for an account. It reports
// (nil, nil) when the unique key refuses the insert because a concurrent
// transfer created the row first, leaving the caller to retry against that row.
func insertERC20Balance(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, error) {
	b := &eventindexer.ERC20Balance{
		ContractAddress: opts.ContractAddress,
		Address:         opts.Address,
		ChainID:         opts.ChainID,
		ERC20MetadataID: opts.ERC20MetadataID,
		Amount:          opts.Amount,
	}

	err := db.Create(b).Error
	if err == nil {
		return b, nil
	}

	if isDuplicateEntry(err) {
		return nil, nil
	}

	return nil, errors.Wrap(err, "r.db.Create")
}

func (r *ERC20BalanceRepository) increaseBalanceInDB(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, error) {
	step := probeBalance

	for attempt := 0; attempt < balanceRaceAttempts; attempt++ {
		if step == probeBalance {
			exists, err := erc20BalanceExists(db, opts)
			if err != nil {
				return nil, err
			}

			step = insertBalance

			if exists {
				step = readBalance
			}
		}

		if step == insertBalance {
			b, err := insertERC20Balance(db, opts)
			if err != nil {
				return nil, err
			}

			// b is nil only when the unique key rejected the insert, which means
			// another transfer won the race and created the row. Re-probing could
			// not see it: this transaction's snapshot predates that insert.
			if b != nil {
				return b, nil
			}

			step = readBalance

			continue
		}

		b, found, err := findERC20BalanceForUpdate(db, opts)
		if err != nil {
			return nil, err
		}

		// The row was drained to zero and deleted by a concurrent transfer, so
		// insert a fresh one. Re-probing would report the deleted row forever,
		// because it still exists in this transaction's snapshot.
		if !found {
			step = insertBalance

			continue
		}

		amt, _ := new(big.Int).SetString(b.Amount, 10)

		optsAmt, _ := new(big.Int).SetString(opts.Amount, 10)

		b.Amount = new(big.Int).Add(amt, optsAmt).String()

		// update the row to reflect new balance
		if err := db.Save(b).Error; err != nil {
			return nil, errors.Wrap(err, "r.db.Save")
		}

		return b, nil
	}

	return nil, errors.Errorf(
		"erc20 balance insert race unresolved after %d attempts: chainID %d, contract %s, address %s",
		balanceRaceAttempts, opts.ChainID, opts.ContractAddress, opts.Address,
	)
}

func (r *ERC20BalanceRepository) decreaseBalanceInDB(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, error) {
	b, found, err := findERC20BalanceForUpdate(db, opts)
	if err != nil {
		return nil, err
	}

	if !found {
		// cant decrease a balance if user never had this balance, indexing issue
		return nil, nil
	}

	amt, _ := new(big.Int).SetString(b.Amount, 10)

	optsAmt, _ := new(big.Int).SetString(opts.Amount, 10)

	b.Amount = new(big.Int).Sub(amt, optsAmt).String()

	// we can just delete the row, this user has no more of this token
	if b.Amount == "0" {
		if err := db.Delete(b).Error; err != nil {
			return nil, errors.Wrap(err, "r.db.Delete")
		}
	} else {
		// update the row instead to reflect new balance
		if err := db.Save(b).Error; err != nil {
			return nil, errors.Wrap(err, "r.db.Save")
		}
	}

	return b, nil
}

func (r *ERC20BalanceRepository) IncreaseAndDecreaseBalancesInTx(
	ctx context.Context,
	ref eventindexer.TransferLogRef,
	increaseOpts eventindexer.UpdateERC20BalanceOpts,
	decreaseOpts eventindexer.UpdateERC20BalanceOpts,
) (increasedBalance *eventindexer.ERC20Balance, decreasedBalance *eventindexer.ERC20Balance, err error) {
	retries := 10
	for retries > 0 {
		var replayed bool

		err = r.db.GormDB().Transaction(func(tx *gorm.DB) (err error) {
			applied, markErr := markTransferLogApplied(ctx, tx, ref)
			if markErr != nil {
				return markErr
			}

			// an earlier pass over this block already applied the log; applying it
			// again would credit the recipient twice.
			if !applied {
				replayed = true

				return nil
			}

			// Skip no-op or zero-address increases to avoid creating balances for 0x000... or zero amount
			if increaseOpts.Amount != "0" && increaseOpts.Amount != "" && increaseOpts.Address != ZeroAddress.Hex() {
				increasedBalance, err = r.increaseBalanceInDB(tx.WithContext(ctx), increaseOpts)
				if err != nil {
					return err
				}
			}

			if decreaseOpts.Amount != "0" && decreaseOpts.Amount != "" {
				decreasedBalance, err = r.decreaseBalanceInDB(tx.WithContext(ctx), decreaseOpts)
			}

			return err
		})

		if err == nil {
			if replayed {
				slog.Debug("skipping replayed erc20 transfer",
					"txHash", ref.TxHash,
					"logIndex", ref.LogIndex,
				)

				return nil, nil, nil
			}

			break
		}

		if strings.Contains(err.Error(), "Deadlock") {
			retries--

			time.Sleep(100 * time.Millisecond) // backoff before retrying

			continue
		}

		return nil, nil, errors.Wrap(err, "r.db.Transaction")
	}

	if err != nil {
		return nil, nil, err
	}

	return increasedBalance, decreasedBalance, nil
}

func (r *ERC20BalanceRepository) FindByAddress(ctx context.Context,
	req *http.Request,
	address string,
	chainID string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Raw("SELECT * FROM erc20_balances WHERE address = ? AND chain_id = ? AND amount > 0", address, chainID)

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]eventindexer.ERC20Balance{})

	return page, nil
}

func (r *ERC20BalanceRepository) FindMetadata(
	ctx context.Context,
	chainID int64,
	contractAddress string,
) (*eventindexer.ERC20Metadata, error) {
	md := eventindexer.ERC20Metadata{}

	result := r.db.GormDB().WithContext(ctx).Raw(
		"SELECT * FROM erc20_metadata WHERE contract_address = ? AND chain_id = ?",
		contractAddress, chainID,
	).Scan(&md)

	if result.Error != nil {
		return nil, result.Error
	}

	if result.RowsAffected == 0 {
		return nil, nil
	}

	return &md, nil
}

func (r *ERC20BalanceRepository) CreateMetadata(
	ctx context.Context,
	chainID int64,
	contractAddress string,
	symbol string,
	decimals uint8,
) (int, error) {
	var id int

	// Start a transaction
	tx := r.db.GormDB().WithContext(ctx).Begin()

	// Insert the new entry
	result := tx.Exec(
		"INSERT INTO erc20_metadata (chain_id, contract_address, symbol, decimals, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())",
		chainID, contractAddress, symbol, decimals,
	)

	if result.Error != nil {
		tx.Rollback()
		return 0, result.Error
	}

	// Retrieve the ID of the newly inserted entry
	err := tx.Raw("SELECT LAST_INSERT_ID()").Scan(&id).Error
	if err != nil {
		tx.Rollback()
		return 0, err
	}

	if err := tx.Commit().Error; err != nil {
		return 0, err
	}

	return id, nil
}
