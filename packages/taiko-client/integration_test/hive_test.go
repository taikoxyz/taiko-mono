package integration_test

import (
	"context"
	"fmt"
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
			"taiko/anvil",
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

	// Single cluster test.
	t.Run("taiko-deneb-testnet/test-deneb-genesis/clusters(1)", func(t *testing.T) {
		testDenebGenesis(t, [][]string{clientGroups[0]})
	})
	t.Run("taiko-deneb-reorg/test-deneb-reorg/clusters(1)", func(t *testing.T) {
		testDenebReorg(t, [][]string{clientGroups[0]})
	})

	// Multi clusters test.
	t.Run(fmt.Sprintf("taiko-deneb-testnet/test-deneb-genesis/clusters(%d)", len(clientGroups)), func(t *testing.T) {
		testDenebGenesis(t, clientGroups)
	})
}

func testDenebGenesis(t *testing.T, clientGroups [][]string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  "taiko-deneb-testnet/test-deneb-genesis",
		ClientGroups:    clientGroups,
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}

func testDenebReorg(t *testing.T, clientGroups [][]string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  "taiko-deneb-reorg/test-deneb-reorg",
		ClientGroups:    clientGroups,
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}
