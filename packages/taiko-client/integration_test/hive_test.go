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
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		DockerOutput:   true,
		BaseDir:        baseDir,
		SimPattern:     "taiko",
		SimTestPattern: "taiko-deneb-testnet/test-deneb-genesis",
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
