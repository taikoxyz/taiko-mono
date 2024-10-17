package integration_test

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/hive/hivesim"
	"github.com/stretchr/testify/assert"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
)

func TestL2NodeGenesisHash(t *testing.T) {
	utils.LoadEnv()
	genesisHash := common.HexToHash("0x01974e6ec215bbe53dac12e24590bf22502f3f30c070dbe5676c062f1e316665")
	client, err := ethclient.Dial(os.Getenv("L2_HTTP"))
	assert.NoError(t, err)
	header, err := client.HeaderByNumber(context.Background(), big.NewInt(0))
	assert.NoError(t, err)
	assert.Equal(t, genesisHash.Hex(), header.Hash().Hex())
}

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
	t.Run(fmt.Sprintf("taiko-genesis/l2-snap-sync/clusters(%d)", len(clientGroups)), func(t *testing.T) {
		testDenebGenesis(t, "taiko-genesis/l2-snap-sync", clientGroups)
	})
	t.Run(fmt.Sprintf("taiko-genesis/l2-full-sync/clusters(%d)", len(clientGroups)), func(t *testing.T) {
		testDenebGenesis(t, "taiko-genesis/l2-full-sync", clientGroups)
	})

	// Multi clusters reorg test.
	t.Run("taiko-reorg/taiko-reorg", func(t *testing.T) {
		testDenebReorg(t, "taiko-reorg/taiko-reorg", [][]string{clientGroups[0]})
	})

	t.Run("taiko-blob/blob-server", func(t *testing.T) {
		testBlobAPI(t, "taiko-blob/blob-server", []string{
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
		})
	})

	t.Run("taiko-blob/blob-l1-beacon", func(t *testing.T) {
		testBlobAPI(t, "taiko-blob/blob-l1-beacon", []string{
			"geth",
			"prysm/prysm-bn",
			"prysm/prysm-vc",
			"taiko/taiko-geth",
			"taiko/driver",
			"taiko/proposer",
			"taiko/prover",
		})
	})
}

func testBlobAPI(t *testing.T, pattern string, clients []string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  pattern,
		ClientGroups:    [][]string{clients},
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}

func testDenebGenesis(t *testing.T, simPattern string, clientGroups [][]string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		DockerPull:      true,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  simPattern,
		ClientGroups:    clientGroups,
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}

func testDenebReorg(t *testing.T, simPattern string, clientGroups [][]string) {
	handler, err := hivesim.NewHiveFramework(&hivesim.HiveConfig{
		BuildOutput:     false,
		ContainerOutput: true,
		DockerPull:      false,
		BaseDir:         os.Getenv("HIVE_DIR"),
		SimPattern:      "taiko",
		SimTestPattern:  simPattern,
		ClientGroups:    clientGroups,
	})
	assert.NoError(t, err)

	failedCount, err := handler.Run(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, 0, failedCount)
}
