package integration_test

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/hive/hivesim"
	"github.com/stretchr/testify/assert"
)

func TestHiveHandler(t *testing.T) {
	baseDir := os.Getenv("HIVE_DIR")
	if baseDir == "" {
		t.SkipNow()
	}

	clientGroups := [][]string{
		{
			"anvil",
			"taiko/taiko-geth",
			"taiko/driver",
			"taiko/proposer",
			"taiko/prover",
		},
		{
			"taiko/taiko-geth",
			"taiko/driver",
		},
		{
			"taiko/taiko-geth",
			"taiko/driver",
		},
	}

	// Multi clusters full sync and snap sync tests.
	t.Run("base/fullsync", func(t *testing.T) {
		hiveFramework(t, true, "base/fullsync", clientGroups)
	})

	// Reorg test.
	t.Run("reorg/reorg", func(t *testing.T) {
		hiveFramework(t, false, "reorg/reorg", [][]string{clientGroups[0]})
	})

	// Preconf tests.
	t.Run("preconf/preconf", func(t *testing.T) {
		hiveFramework(t, false, "preconf/preconf", [][]string{
			{
				"anvil",
				"taiko/taiko-geth",
				"taiko/driver",
				"taiko/proposer",
			},
			{
				"taiko/taiko-geth",
				"taiko/driver",
			},
		})
	})

	t.Run("preconf/reorg", func(t *testing.T) {
		hiveFramework(t, false, "preconf/reorg", [][]string{
			{
				"anvil",
				"taiko/taiko-geth",
				"taiko/driver",
				"taiko/proposer",
			},
		})
	})

	t.Run("preconf/forced-inclusion", func(t *testing.T) {
		hiveFramework(t, false, "preconf/forced-inclusion", [][]string{
			{
				"geth",
				"prysm/prysm-bn",
				"prysm/prysm-vc",
				"taiko/taiko-geth",
				"taiko/driver",
				"taiko/proposer",
			},
		})
	})

	t.Run("blob/blob-server", func(t *testing.T) {
		hiveFramework(t, false, "blob/blob-server", [][]string{
			{
				"geth",
				"prysm/prysm-bn",
				"prysm/prysm-vc",
				"taiko/taiko-geth",
				"taiko/driver",
				"taiko/proposer",
				"taiko/prover",
				"storage/redis",
				"storage/postgres",
				"blobscan/blobscan-api",
				"blobscan/blobscan-indexer",
			},
		})
	})

	t.Run("blob/blob-l1-beacon", func(t *testing.T) {
		hiveFramework(t, false, "blob/blob-l1-beacon", [][]string{
			{
				"geth",
				"prysm/prysm-bn",
				"prysm/prysm-vc",
				"taiko/taiko-geth",
				"taiko/driver",
				"taiko/proposer",
				"taiko/prover",
			},
		})
	})
}

func hiveFramework(t *testing.T, dockerPull bool, simPattern string, clientGroups [][]string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		DockerPull:      dockerPull,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  simPattern,
		SimLogLevel:     2,
		ClientGroups:    clientGroups,
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}
