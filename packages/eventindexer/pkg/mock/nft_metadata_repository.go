package mock

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type NFTMetadataRepository struct {
	nftMetadata []*eventindexer.NFTMetadata
}

func NewNFTMetadataRepository() *NFTMetadataRepository {
	return &NFTMetadataRepository{}
}

func (r *NFTMetadataRepository) FindByContractAddress(
	ctx context.Context,
	req *http.Request,
	contractAddress string) (paginate.Page, error) {
	var metadata []*eventindexer.NFTMetadata

	for _, b := range r.nftMetadata {
		if b.ContractAddress == contractAddress {
			metadata = append(metadata, b)
		}
	}

	return paginate.Page{
		Items: metadata,
	}, nil
}

func (r *NFTMetadataRepository) GetNFTMetadata(
	ctx context.Context,
	contractAddress string,
	tokenID int64,
	chainID int64,
) (*eventindexer.NFTMetadata, error) {
	for _, metadata := range r.nftMetadata {
		if metadata.ContractAddress == contractAddress && metadata.TokenID == tokenID {
			return metadata, nil
		}
	}

	return nil, nil
}

func (r *NFTMetadataRepository) SaveNFTMetadata(
	ctx context.Context,
	metadata *eventindexer.NFTMetadata) (*eventindexer.NFTMetadata, error) {
	r.nftMetadata = append(r.nftMetadata, metadata)

	return metadata, nil
}
