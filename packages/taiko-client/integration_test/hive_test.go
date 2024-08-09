package integration_test

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/hive/hivesim"
	"github.com/stretchr/testify/assert"
)

func TestHiveHandler(t *testing.T) {
	baseDir := os.Getenv("HIVE_BASE_DIR")
	if baseDir == "" {
		t.SkipNow()
	}
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BaseDir:        baseDir,
		SimPattern:     "taiko2",
		SimTestPattern: "eth2-deneb-testnet/test-deneb-genesis",
		Clients: []string{
			"taiko2/geth",
			"taiko2/prysm-bn",
			"taiko2/prysm-vc",
			"taiko2/taiko-geth",
			"taiko2/driver",
			"taiko2/proposer",
			"taiko2/prover",
		},
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}
