package eventindexer

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

// NFTBalance represents a single contractAddress/tokenId pairing for a given holder
// address
type NFTBalance struct {
	ID              int
	ChainID         int64
	Address         string
	Amount          int64
	TokenID         int64
	ContractAddress string
	ContractType    string
}

type UpdateNFTBalanceOpts struct {
	ChainID         int64
	Address         string
	TokenID         int64
	ContractAddress string
	ContractType    string
	Amount          int64
}

// NFTBalanceRepository is used to interact with nft balances in the store
type NFTBalanceRepository interface {
	SubtractBalance(ctx context.Context, opts UpdateNFTBalanceOpts) (*NFTBalance, error)
	IncreaseBalance(ctx context.Context, opts UpdateNFTBalanceOpts) (*NFTBalance, error)
	FindByAddress(ctx context.Context,
		req *http.Request,
		address string,
		chainID string,
	) (paginate.Page, error)
}
