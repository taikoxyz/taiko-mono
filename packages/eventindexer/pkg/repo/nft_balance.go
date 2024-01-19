package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
)

type NFTBalanceRepository struct {
	db eventindexer.DB
}

func NewNFTBalanceRepository(db eventindexer.DB) (*NFTBalanceRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &NFTBalanceRepository{
		db: db,
	}, nil
}

func (r *NFTBalanceRepository) IncreaseBalance(
	ctx context.Context,
	opts eventindexer.UpdateNFTBalanceOpts,
) (*eventindexer.NFTBalance, error) {
	b := &eventindexer.NFTBalance{
		ContractAddress: opts.ContractAddress,
		TokenID:         opts.TokenID,
		Address:         opts.Address,
		ContractType:    opts.ContractType,
		ChainID:         opts.ChainID,
		Amount:          0,
	}

	err := r.db.
		GormDB().
		Where("contract_address = ?", opts.ContractAddress).
		Where("token_id = ?", opts.TokenID).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		First(b).
		Error
	if err != nil {
		// allow to be not found, it may be first time this user has this NFT
		if err != gorm.ErrRecordNotFound {
			return nil, errors.Wrap(err, "r.db.gormDB.First")
		}
	}

	b.Amount += opts.Amount

	// update the row to reflect new balance
	if err := r.db.GormDB().Save(b).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Save")
	}

	return b, nil
}

func (r *NFTBalanceRepository) SubtractBalance(
	ctx context.Context,
	opts eventindexer.UpdateNFTBalanceOpts,
) (*eventindexer.NFTBalance, error) {
	b := &eventindexer.NFTBalance{
		ContractAddress: opts.ContractAddress,
		TokenID:         opts.TokenID,
		Address:         opts.Address,
		ContractType:    opts.ContractType,
		ChainID:         opts.ChainID,
	}

	err := r.db.
		GormDB().
		Where("contract_address = ?", opts.ContractAddress).
		Where("token_id = ?", opts.TokenID).
		Where("address = ?", opts.Address).
		Where("chain_id = ?", opts.ChainID).
		First(b).
		Error
	if err != nil {
		if err != gorm.ErrRecordNotFound {
			return nil, errors.Wrap(err, "r.db.gormDB.First")
		} else {
			// cant subtract a balance if user never had this balance, indexing issue
			return nil, nil
		}
	}

	b.Amount -= opts.Amount

	// we can just delete the row, this user has no more of this NFT
	if b.Amount == 0 {
		if err := r.db.GormDB().Delete(b).Error; err != nil {
			return nil, errors.Wrap(err, "r.db.Delete")
		}
	} else {
		// update the row instead to reflect new balance
		if err := r.db.GormDB().Save(b).Error; err != nil {
			return nil, errors.Wrap(err, "r.db.Save")
		}
	}

	return b, nil
}

func (r *NFTBalanceRepository) FindByAddress(ctx context.Context,
	req *http.Request,
	address string,
	chainID string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Raw("SELECT * FROM nft_balances WHERE address = ? AND chain_id = ? AND amount > 0", address, chainID)

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]eventindexer.NFTBalance{})

	return page, nil
}
