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
	t.Run("taiko-deneb-testnet/test-deneb-genesis", testDenebGenesis)
	t.Run("taiko-deneb-reorg/test-deneb-reorg", testDenebReorg)

}

func testDenebGenesis(t *testing.T) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  "taiko-deneb-testnet/test-deneb-genesis",
		Clients: []string{
			"taiko/geth",
			"taiko/prysm-bn",
			"taiko/prysm-vc",
			"taiko/taiko-geth",
			"taiko/driver",
			"taiko/proposer",
			"taiko/prover",
		},
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}

func testDenebReorg(t *testing.T) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		DockerPull:      false,
		BuildOutput:     false,
		ContainerOutput: true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  "taiko-deneb-reorg/test-deneb-reorg",
		Clients: []string{
			"taiko/anvil",
			"taiko/taiko-geth",
			"taiko/driver",
			"taiko/proposer",
			"taiko/prover",
		},
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}
