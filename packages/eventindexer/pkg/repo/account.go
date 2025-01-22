package repo

import (
	"context"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
)

type AccountRepository struct {
	db db.DB
}

func NewAccountRepository(dbHandler db.DB) (*AccountRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &AccountRepository{
		db: dbHandler,
	}, nil
}

func (r *AccountRepository) Save(
	ctx context.Context,
	address common.Address,
	transactedAt time.Time,
) error {
	// only insert if address doesn't exist
	a := &eventindexer.Account{}

	if err := r.db.GormDB().WithContext(ctx).Where("address = ?", address.Hex()).First(a).Error; err != nil {
		if err != gorm.ErrRecordNotFound {
			return err
		}
	}

	if a.ID == 0 {
		t := &eventindexer.Account{
			Address:      address.Hex(),
			TransactedAt: transactedAt,
		}

		if err := r.db.GormDB().Create(t).Error; err != nil {
			if strings.Contains(err.Error(), "Duplicate") {
				return nil
			}

			return errors.Wrap(err, "r.db.Create")
		}
	}

	return nil
}
