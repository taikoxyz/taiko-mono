package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	BlockBatchSize = &cli.Uint64Flag{
		Name:     "blockBatchSize",
		Usage:    "Block batch size when iterating through blocks",
		Value:    10,
		Category: indexerCategory,
		EnvVars:  []string{"BLOCK_BATCH_SIZE"},
	}
	MaxNumGoroutines = &cli.Uint64Flag{
		Name:     "maxNumGoroutines",
		Usage:    "Max number of goroutines to spawn simultaneously when indexing",
		Value:    10,
		Category: indexerCategory,
		EnvVars:  []string{"NUM_GOROUTINES"},
	}
	SubscriptionBackoff = &cli.Uint64Flag{
		Name:     "subscriptionBackoff",
		Usage:    "Subscription backoff in seconds",
		Value:    30,
		Category: indexerCategory,
		EnvVars:  []string{"SUBSCRIPTION_BACKOFF_IN_SECONDS"},
	}
)

var IndexerFlags = MergeFlags(CommonFlags, []cli.Flag{
	BlockBatchSize,
})
