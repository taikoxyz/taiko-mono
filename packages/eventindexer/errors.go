package eventindexer

import "github.com/cyberhorsey/errors"

var (
	ErrNoNFTBalanceRepository = errors.Validation.NewWithKeyAndDetail("ERR_NO_NFT_BALANCE_REPOSITORY", "NFTBalanceRepository is required")
	ErrNFTIndexingDisabled    = errors.Validation.NewWithKeyAndDetail("ERR_NFT_INDEXING_DISABLED", "NFT indexing must be enabled")
	ErrInvalidBlockBatchSize  = errors.Validation.NewWithKeyAndDetail("ERR_INVALID_BLOCK_BATCH_SIZE", "Block batch size must be greater than zero")
	ErrInvalidMode            = errors.Validation.NewWithKeyAndDetail("ERR_INVALID_MODE", "Mode not supported")
)
