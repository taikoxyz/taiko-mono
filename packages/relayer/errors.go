package relayer

import "github.com/cyberhorsey/errors"

var (
	ErrNoEthClient       = errors.Validation.NewWithKeyAndDetail("ERR_NO_ETH_CLIENT", "EthClient is required")
	ErrNoECDSAKey        = errors.Validation.NewWithKeyAndDetail("ERR_NO_ECDSA_KEY", "ECDSAKey is required")
	ErrNoBridgeAddress   = errors.Validation.NewWithKeyAndDetail("ERR_NO_BRIDGE_ADDRESS", "BridgeAddress is required")
	ErrNoEventRepository = errors.Validation.NewWithKeyAndDetail("ERR_NO_EVENT_REPOSITORY", "EventRepository is required")
	ErrNoBlockRepository = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_BLOCK_REPOSITORY",
		"BlockRepository is required",
	)
	ErrNoProver      = errors.Validation.NewWithKeyAndDetail("ERR_NO_PROVER", "Prover is required")
	ErrNoRPCClient   = errors.Validation.NewWithKeyAndDetail("ERR_NO_RPC_CLIENT", "RPCClient is required")
	ErrNoBridge      = errors.Validation.NewWithKeyAndDetail("ERR_NO_BRIDGE", "Bridge is required")
	ErrNoTaikoL2     = errors.Validation.NewWithKeyAndDetail("ERR_NO_TAIKO_L2", "TaikoL2 is required")
	ErrNoCORSOrigins = errors.Validation.NewWithKeyAndDetail("ERR_NO_CORS_ORIGINS", "CORS Origins are required")
)
