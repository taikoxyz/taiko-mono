package eventindexer

import "github.com/cyberhorsey/errors"

var (
	ErrNoEthClient       = errors.Validation.NewWithKeyAndDetail("ERR_NO_ETH_CLIENT", "EthClient is required")
	ErrNoEventRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_EVENT_REPOSITORY",
		"EventRepository is required",
	)
	ErrNoNFTBalanceRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_NFT_BALANCE_REPOSITORY",
		"NFTBalanceRepository is required",
	)
	ErrNoNFTMetadataRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_NFT_METADATA_REPOSITORY",
		"NFTMetadataRepository is required",
	)
	ErrNoStatRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_STAT_REPOSITORY",
		"StatRepository is required",
	)
	ErrNoBlockRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_BLOCK_REPOSITORY",
		"BlockRepository is required",
	)
	ErrNoCORSOrigins = errors.Validation.NewWithKeyAndDetail("ERR_NO_CORS_ORIGINS", "CORS Origins are required")
	ErrNoRPCClient   = errors.Validation.NewWithKeyAndDetail("ERR_NO_RPC_CLIENT", "RPCClient is required")
	ErrInvalidMode   = errors.Validation.NewWithKeyAndDetail("ERR_INVALID_MODE", "Mode not supported")
	ErrInvalidURL    = errors.Validation.NewWithKeyAndDetail("ERR_INVALID_URL", "The provided URL is invalid or unreachable")
)
