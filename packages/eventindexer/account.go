package eventindexer

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"
)

type Account struct {
	ID           int       `json:"id"`
	Address      string    `json:"address"`
	TransactedAt time.Time `json:"transactedAt"`
}

type AccountRepository interface {
	Save(ctx context.Context, address common.Address, transactedAt time.Time) error
}
