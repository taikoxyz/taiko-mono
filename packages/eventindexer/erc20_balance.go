package eventindexer

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

type ERC20Metadata struct {
	ID              int    `json:"id"`
	ChainID         int64  `json:"chainID"`
	ContractAddress string `json:"contractAddress"`
	Symbol          string `json:"symbol"`
	Decimals        uint8  `json:"decimals"`
}

// ERC20Balance
type ERC20Balance struct {
	ID              int            `json:"id"`
	ERC20MetadataID int64          `json:"erc20MetadataID"`
	ChainID         int64          `json:"chainID"`
	Address         string         `json:"address"`
	Amount          string         `json:"amount"`
	ContractAddress string         `json:"contractAddress"`
	Metadata        *ERC20Metadata `json:"metadata" gorm:"foreignKey:ERC20MetadataID"`
}

type UpdateERC20BalanceOpts struct {
	ERC20MetadataID int64
	ChainID         int64
	Address         string
	ContractAddress string
	Amount          string
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
	FindMetadata(ctx context.Context, chainID int64, contractAddress string) (*ERC20Metadata, error)
	CreateMetadata(
		ctx context.Context,
		chainID int64,
		contractAddress string,
		symbol string,
		decimals uint8,
	) (int, error)
}
