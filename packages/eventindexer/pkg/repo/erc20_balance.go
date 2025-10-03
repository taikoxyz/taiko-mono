package repo

import (
	"context"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
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

func (r *ERC20BalanceRepository) increaseBalanceInDB(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, error) {
	b := &eventindexer.ERC20Balance{
		ContractAddress: opts.ContractAddress,
		Address:         opts.Address,
		ChainID:         opts.ChainID,
		ERC20MetadataID: opts.ERC20MetadataID,
		Amount:          "0",
	}

	err := db.
		Where("contract_address = ?", opts.ContractAddress).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		First(b).
		Error
	if err != nil {
		// allow to be not found, it may be first time this user has this token
		if err != gorm.ErrRecordNotFound {
			return nil, errors.Wrap(err, "r.db.gormDB.First")
		}
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

func (r *ERC20BalanceRepository) decreaseBalanceInDB(
	db *gorm.DB,
	opts eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, error) {
	b := &eventindexer.ERC20Balance{
		ContractAddress: opts.ContractAddress,
		Address:         opts.Address,
		ChainID:         opts.ChainID,
		ERC20MetadataID: opts.ERC20MetadataID,
	}

	err := db.
		Where("contract_address = ?", opts.ContractAddress).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		First(b).
		Error
	if err != nil {
		if err != gorm.ErrRecordNotFound {
			return nil, errors.Wrap(err, "r.db.gormDB.First")
		} else {
			// cant decrease a balance if user never had this balance, indexing issue
			return nil, nil
		}
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
	increaseOpts eventindexer.UpdateERC20BalanceOpts,
	decreaseOpts eventindexer.UpdateERC20BalanceOpts,
) (increasedBalance *eventindexer.ERC20Balance, decreasedBalance *eventindexer.ERC20Balance, err error) {
	retries := 10
	for retries > 0 {
		err = r.db.GormDB().Transaction(func(tx *gorm.DB) (err error) {
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

	tx.Commit()

	return id, nil
}
