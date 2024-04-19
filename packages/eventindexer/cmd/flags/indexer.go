package flags

import "github.com/urfave/cli/v2"

// required flags
var (
	IndexerRPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"RPC_URL"},
	}
)

// optional flags
var (
	ETHClientTimeout = &cli.Uint64Flag{
		Name:     "ethClientTimeout",
		Usage:    "Timeout for eth client and contract binding calls",
		Category: indexerCategory,
		Required: false,
		Value:    10,
		EnvVars:  []string{"ETH_CLIENT_TIMEOUT"},
	}
	L1TaikoAddress = &cli.StringFlag{
		Name:     "l1TaikoAddress",
		Usage:    "Address of the TaikoL1 contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"L1_TAIKO_ADDRESS"},
	}
	BridgeAddress = &cli.StringFlag{
		Name:     "bridgeAddress",
		Usage:    "Address of the Bridge contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"BRIDGE_ADDRESS"},
	}
	SwapAddresses = &cli.StringFlag{
		Name:     "swapAddresses",
		Usage:    "Comma-delinated list of Swap contract addresses",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"SWAP_ADDRESSES"},
	}
	AssignmentHookAddress = &cli.StringFlag{
		Name:     "assignmentHookAddress",
		Usage:    "Address of the AssignmentHook contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"ASSIGNMENT_HOOK_ADDRESS"},
	}
	SgxVerifierAddress = &cli.StringFlag{
		Name:     "sgxVerifierAddress",
		Usage:    "Address of the SGXVerifier contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"SGX_VERIFIER_ADDRESS"},
	}
	BlockBatchSize = &cli.Uint64Flag{
		Name:     "blockBatchSize",
		Usage:    "Block batch size when iterating through blocks",
		Value:    10,
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"BLOCK_BATCH_SIZE"},
	}
	SubscriptionBackoff = &cli.Uint64Flag{
		Name:     "subscriptionBackoff",
		Usage:    "Subscription backoff in seconds",
		Value:    30,
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"SUBSCRIPTION_BACKOFF_IN_SECONDS"},
	}
	SyncMode = &cli.StringFlag{
		Name:     "syncMode",
		Usage:    "Mode of syncing. Pass in 'sync' to continue, and 'resync' to start from genesis again.",
		Value:    "sync",
		Category: indexerCategory,
		EnvVars:  []string{"SYNC_MODE"},
	}
	IndexNFTs = &cli.BoolFlag{
		Name:     "indexNfts",
		Usage:    "Whether to index nft transfer events or not",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"INDEX_NFTS"},
	}
)

var IndexerFlags = MergeFlags(CommonFlags, []cli.Flag{
	IndexerRPCUrl,
	// optional
	ETHClientTimeout,
	L1TaikoAddress,
	BridgeAddress,
	SwapAddresses,
	SgxVerifierAddress,
	AssignmentHookAddress,
	BlockBatchSize,
	SubscriptionBackoff,
	SyncMode,
	IndexNFTs,
})
