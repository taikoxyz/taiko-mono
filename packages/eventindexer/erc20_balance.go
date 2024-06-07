package eventindexer

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

// ERC20Balance
type ERC20Balance struct {
	ID              int    `json:"id"`
	ERC20MetadataID int64  `json:"erc20MetadataID"`
	ChainID         int64  `json:"chainID"`
	Address         string `json:"address"`
	Amount          int64  `json:"amount"`
	ContractAddress string `json:"contractAddress"`
}

type UpdateERC20BalanceOpts struct {
	ERC20MetadataID int64
	ChainID         int64
	Address         string
	ContractAddress string
	Amount          int64
}

// ERC20BalanceRepository is used to interact with nft balances in the store
type ERC20BalanceRepository interface {
	IncreaseAndDecreaseBalancesInTx(
		ctx context.Context,
		increaseOpts UpdateERC20BalanceOpts,
		decreaseOpts UpdateERC20BalanceOpts,
	) (increasedBalance *ERC20Balance, decreasedBalance *ERC20Balance, err error)
	FindByAddress(ctx context.Context,
		req *http.Request,
		address string,
		chainID string,
	) (paginate.Page, error)
	FindMetadata(ctx context.Context, chainID int64, contractAddress string) (int, error)
	CreateMetadata(
		ctx context.Context,
		chainID int64,
		contractAddress string,
		symbol string,
	) (int, error)
}
