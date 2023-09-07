package eventindexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/shopspring/decimal"
)

type Transaction struct {
	ID        int                 `json:"id"`
	ChainID   int64               `json:"chainID"`
	Sender    string              `json:"sender"`
	Recipient string              `json:"recipient"`
	BlockID   int64               `json:"blockID"`
	Amount    decimal.NullDecimal `json:"amount"`
	GasPrice  string              `json:"gasPrice"`
}

type TransactionRepository interface {
	Save(ctx context.Context, tx *types.Transaction, sender common.Address, blockID *big.Int) error
}
