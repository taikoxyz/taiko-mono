package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	ProcessorPrivateKey = &cli.StringFlag{
		Name:     "processorPrivateKey",
		Usage:    "Private key to process messages on the destination chain",
		Required: true,
		Category: processorCategory,
		EnvVars:  []string{"PROCESSOR_PRIVATE_KEY"},
	}
	DestTaikoAddress = &cli.StringFlag{
		Name:     "destTaikoAddress",
		Usage:    "Taiko address for the destination chain",
		Required: true,
		Category: processorCategory,
		EnvVars:  []string{"DEST_TAIKO_ADDRESS"},
	}
	DestERC20VaultAddress = &cli.StringFlag{
		Name:     "destERC20VaultAddress",
		Usage:    "ERC20Vault address for the destination chain, only required if you want to process NFTs",
		Category: processorCategory,
		Required: true,
		EnvVars:  []string{"DEST_ERC20_VAULT_ADDRESS"},
	}
	DestERC1155VaultAddress = &cli.StringFlag{
		Name:     "destERC1155Address",
		Usage:    "ERC1155Vault address for the destination chain",
		Category: processorCategory,
		Required: true,
		EnvVars:  []string{"DEST_ERC1155_VAULT_ADDRESS"},
	}
	DestERC721VaultAddress = &cli.StringFlag{
		Name:     "destERC721Address",
		Usage:    "ERC721Vault address for the destination chain",
		Category: processorCategory,
		Required: true,
		EnvVars:  []string{"DEST_ERC721_VAULT_ADDRESS"},
	}
)

// optional
var (
	HeaderSyncInterval = &cli.Uint64Flag{
		Name:     "headerSyncInterval",
		Usage:    "Interval to poll to see if header is synced yet, in seconds",
		Value:    10,
		Category: processorCategory,
		EnvVars:  []string{"HEADER_SYNC_INTERVAL_IN_SECONDS"},
	}
	Confirmations = &cli.Uint64Flag{
		Name:     "confirmations",
		Usage:    "Confirmations to wait for on source chain before processing on destination chain",
		Value:    3,
		Category: processorCategory,
		EnvVars:  []string{"CONFIRMATIONS_BEFORE_PROCESSING"},
	}
	ConfirmationTimeout = &cli.Uint64Flag{
		Name:     "confirmationTimeout",
		Usage:    "Timeout when waiting for a processed message receipt in seconds",
		Value:    360,
		Category: processorCategory,
		EnvVars:  []string{"CONFIRMATIONS_TIMEOUT_IN_SECONDS"},
	}
	ProfitableOnly = &cli.BoolFlag{
		Name:     "profitableOnly",
		Usage:    "Whether to only process transactions that are estimated to be profitable",
		Value:    false,
		Category: processorCategory,
		EnvVars:  []string{"PROFITABLE_ONLY"},
	}
	QueuePrefetchCount = &cli.Uint64Flag{
		Name:     "queue.prefetch",
		Usage:    "How many messages to prefetch",
		Category: processorCategory,
		Value:    1,
		EnvVars:  []string{"QUEUE_PREFETCH_COUNT"},
	}
	EnableTaikoL2 = &cli.BoolFlag{
		Name:     "enableTaikoL2",
		Usage:    "Whether to instantiate a taikoL2 contract based off the config.DestTaikoAddress",
		Value:    false,
		Category: processorCategory,
		EnvVars:  []string{"ENABLE_TAIKO_L2"},
	}
	HopSignalServiceAddresses = &cli.StringSliceFlag{
		Name:     "hopSignalServiceAddresses",
		Usage:    "SignalService addresses for the intermediary chains",
		Required: false,
		Category: processorCategory,
		EnvVars:  []string{"HOP_SIGNAL_SERVICE_ADDRESSES"},
	}
	HopTaikoAddresses = &cli.StringSliceFlag{
		Name:     "hopTaikoAddresses",
		Usage:    "Taiko addresses for the intermediary chains",
		Required: false,
		Category: processorCategory,
		EnvVars:  []string{"HOP_TAIKO_ADDRESSES"},
	}
	HopRPCUrls = &cli.StringSliceFlag{
		Name:     "hopRpcUrls",
		Usage:    "RPC URL for the intermediary chains",
		Required: false,
		Category: processorCategory,
		EnvVars:  []string{"HOP_RPC_URLS"},
	}
	TargetTxHash = &cli.StringFlag{
		Name:     "targetTxHash",
		Usage:    "Target transaction hash, set to ignore processing from queue and only process this individual transaction",
		Category: processorCategory,
		Required: false,
		EnvVars:  []string{"TARGET_TX_HASH"},
	}
	CacheOption = &cli.IntFlag{
		Name:     "cacheOption",
		Usage:    "Cache option. Options: 0 - cache nothing, 1 - cache signal root, 2 - cache state root, 3 - cache both",
		Category: processorCategory,
		Required: false,
		EnvVars:  []string{"CACHE_OPTION"},
		Value:    3,
	}
	UnprofitableMessageQueueExpiration = &cli.StringFlag{
		Name:     "unprofitableMessageQueueExpiration",
		Usage:    "Time in seconds for queue message to expire when unprofitable, which will re-route it to be checked again",
		Category: processorCategory,
		Required: false,
		EnvVars:  []string{"UNPROFITABLE_MESSAGE_QUEUE_EXPIRATION"},
	}
)

var ProcessorFlags = MergeFlags(CommonFlags, QueueFlags, TxmgrFlags, []cli.Flag{
	DestERC721VaultAddress,
	DestERC1155VaultAddress,
	DestERC20VaultAddress,
	DestTaikoAddress,
	ProcessorPrivateKey,
	// optional
	HeaderSyncInterval,
	Confirmations,
	ConfirmationTimeout,
	ProfitableOnly,
	QueuePrefetchCount,
	EnableTaikoL2,
	HopRPCUrls,
	HopSignalServiceAddresses,
	HopTaikoAddresses,
	DestBridgeAddress,
	TargetTxHash,
	CacheOption,
	UnprofitableMessageQueueExpiration,
})
