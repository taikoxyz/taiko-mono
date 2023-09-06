package eventindexer

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/shopspring/decimal"
)

type Transaction struct {
	ID       int                 `json:"id"`
	ChainID  int64               `json:"chainID"`
	From     string              `json:"from"`
	To       string              `json:"to"`
	BlockID  int64               `json:"blockID"`
	Value    decimal.NullDecimal `json:"value"`
	GasPrice string              `json:"gasPrice"`
}

type TransactionRepository interface {
	Save(ctx context.Context, tx *types.Transaction, sender common.Address) error
}
