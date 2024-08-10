package eventindexer

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

// NFTBalance represents a single contractAddress/tokenId pairing for a given holder
// address
type NFTBalance struct {
	ID              int          `json:"id"`
	NftMetadataId   int64        `json:"nftMetadataId"`
	ChainID         int64        `json:"chainID"`
	Address         string       `json:"address"`
	Amount          int64        `json:"amount"`
	TokenID         int64        `json:"tokenID"`
	ContractAddress string       `json:"contractAddress"`
	ContractType    string       `json:"contractType"`
	Metadata        *NFTMetadata `json:"metadata" gorm:"foreignKey:NftMetadataId"`
}

type UpdateNFTBalanceOpts struct {
	NftMetadataId   int64
	ChainID         int64
	Address         string
	TokenID         int64
	ContractAddress string
	ContractType    string
	Amount          int64
}

// NFTBalanceRepository is used to interact with nft balances in the store
type NFTBalanceRepository interface {
	IncreaseAndDecreaseBalancesInTx(
		ctx context.Context,
		increaseOpts UpdateNFTBalanceOpts,
		decreaseOpts UpdateNFTBalanceOpts,
	) (increasedBalance *NFTBalance, decreasedBalance *NFTBalance, err error)
	FindByAddress(ctx context.Context,
		req *http.Request,
		address string,
		chainID string,
	) (paginate.Page, error)
}
