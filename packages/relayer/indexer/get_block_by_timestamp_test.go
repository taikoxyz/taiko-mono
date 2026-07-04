package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
)

// mockEthClientWithBlocks allows custom block/timestamp configuration for testing
type mockEthClientWithBlocks struct {
	blocks map[uint64]*types.Header
	latest uint64
}

func (m *mockEthClientWithBlocks) ChainID(ctx context.Context) (*big.Int, error) {
	return big.NewInt(1), nil
}

func (m *mockEthClientWithBlocks) HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error) {
	if number == nil {
		return m.blocks[m.latest], nil
	}

	blockNum := number.Uint64()
	if header, exists := m.blocks[blockNum]; exists {
		return header, nil
	}

	// Generate header on the fly for binary search
	return &types.Header{
		Number: number,
		Time:   m.calculateTimestamp(blockNum),
	}, nil
}

func (m *mockEthClientWithBlocks) BlockNumber(ctx context.Context) (uint64, error) {
	return m.latest, nil
}

func (m *mockEthClientWithBlocks) TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error) {
	return nil, nil
}

func (m *mockEthClientWithBlocks) SubscribeNewHead(
	ctx context.Context,
	ch chan<- *types.Header,
) (ethereum.Subscription, error) {
	return nil, nil
}

func (m *mockEthClientWithBlocks) TransactionByHash(
	ctx context.Context,
	txHash common.Hash,
) (*types.Transaction, bool, error) {
	return nil, false, nil
}

func (m *mockEthClientWithBlocks) calculateTimestamp(blockNum uint64) uint64 {
	// Simulate 12s block time from genesis
	genesisTime := m.blocks[1].Time
	return genesisTime + (blockNum-1)*12
}

func Test_getBlockByTimestamp(t *testing.T) {
	tests := []struct {
		name            string
		latestBlock     uint64
		latestTimestamp uint64
		genesisTime     uint64
		targetTimestamp uint64
		wantBlock       uint64
		wantDelta       float64 // tolerance for binary search
		wantErr         bool
	}{
		{
			name:            "underflow case - very old timestamp on small chain",
			latestBlock:     500,
			latestTimestamp: 6000,
			genesisTime:     0,
			targetTimestamp: 0,
			wantBlock:       1,
			wantDelta:       0,
			wantErr:         false,
		},
		{
			name:            "underflow case - estimatedBlocksBack > latestBlock",
			latestBlock:     100,
			latestTimestamp: 5000,
			genesisTime:     0,
			targetTimestamp: 100,
			wantBlock:       9,
			wantDelta:       10,
			wantErr:         false,
		},
		{
			name:            "normal case - mid-chain timestamp",
			latestBlock:     1000,
			latestTimestamp: 11988, // 1000 blocks * 12s - 12s for genesis
			genesisTime:     0,
			targetTimestamp: 5988, // ~500 blocks
			wantBlock:       500,
			wantDelta:       10,
			wantErr:         false,
		},
		{
			name:            "boundary - target equals latest",
			latestBlock:     1000,
			latestTimestamp: 11988,
			genesisTime:     0,
			targetTimestamp: 11988,
			wantBlock:       1000,
			wantDelta:       0,
			wantErr:         false,
		},
		{
			name:            "boundary - target before genesis",
			latestBlock:     1000,
			latestTimestamp: 11988,
			genesisTime:     100,
			targetTimestamp: 50,
			wantBlock:       1,
			wantDelta:       0,
			wantErr:         false,
		},
		{
			name:            "recent block - within margin",
			latestBlock:     10000,
			latestTimestamp: 119988, // 10000 blocks * 12s - 12s
			genesisTime:     0,
			targetTimestamp: 118788, // ~100 blocks back
			wantBlock:       9900,
			wantDelta:       10,
			wantErr:         false,
		},
		{
			name:            "small chain - latestBlock = 1",
			latestBlock:     1,
			latestTimestamp: 100,
			genesisTime:     100,
			targetTimestamp: 100,
			wantBlock:       1,
			wantDelta:       0,
			wantErr:         false,
		},
		{
			name:            "small chain - targetTimestamp = 0",
			latestBlock:     10,
			latestTimestamp: 108,
			genesisTime:     0,
			targetTimestamp: 0,
			wantBlock:       1,
			wantDelta:       0,
			wantErr:         false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock client with test data
			mockClient := &mockEthClientWithBlocks{
				blocks: map[uint64]*types.Header{
					1: {
						Number: big.NewInt(1),
						Time:   tt.genesisTime,
					},
					tt.latestBlock: {
						Number: big.NewInt(int64(tt.latestBlock)),
						Time:   tt.latestTimestamp,
					},
				},
				latest: tt.latestBlock,
			}

			indexer := &Indexer{
				srcEthClient: mockClient,
				ctx:          context.Background(),
			}

			result, err := indexer.getBlockByTimestamp(context.Background(), tt.targetTimestamp)

			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				// Allow tolerance for binary search
				if tt.wantDelta > 0 {
					assert.InDelta(t, tt.wantBlock, result, tt.wantDelta,
						"Expected block ~%d, got %d", tt.wantBlock, result)
				} else {
					assert.Equal(t, tt.wantBlock, result,
						"Expected block %d, got %d", tt.wantBlock, result)
				}
				// Verify result is in valid range
				assert.GreaterOrEqual(t, result, uint64(1), "Result should be >= 1")
				assert.LessOrEqual(t, result, tt.latestBlock, "Result should be <= latestBlock")
			}
		})
	}
}

func Test_getBlockByTimestamp_UnderflowRegression(t *testing.T) {
	// Specific regression test for the reported vulnerability
	// Scenario: Small chain with very old target timestamp that would cause
	// estimatedBlocksBack > latestBlock
	mockClient := &mockEthClientWithBlocks{
		blocks: map[uint64]*types.Header{
			1: {
				Number: big.NewInt(1),
				Time:   0,
			},
			500: {
				Number: big.NewInt(500),
				Time:   3000, // Very fast blocks - 6s average instead of 12s
			},
		},
		latest: 500,
	}

	indexer := &Indexer{
		srcEthClient: mockClient,
		ctx:          context.Background(),
	}

	// With avgBlockTime = 12s and actual = 6s:
	// timeDiff = 3000 - 0 = 3000
	// estimatedBlocksBack = 3000 / 12 = 250
	// OLD CODE: estimatedBlock = 500 - 250 = 250 (safe by luck)
	//
	// But if target is very old:
	// targetTimestamp = 0
	// timeDiff = 3000
	// estimatedBlocksBack = 250
	// This is safe, but let's test a case where it would underflow
	//
	// To trigger underflow, we need estimatedBlocksBack > latestBlock
	// timeDiff needs to be > latestBlock * avgBlockTime
	// With latestBlock=500, avgBlockTime=12: timeDiff > 6000
	// But latestTimestamp is only 3000, so max timeDiff = 3000
	//
	// Let's make latestBlock smaller
	mockClient.latest = 100
	mockClient.blocks[100] = &types.Header{
		Number: big.NewInt(100),
		Time:   3000,
	}
	delete(mockClient.blocks, 500)

	// Now: timeDiff = 3000, estimatedBlocksBack = 250, latestBlock = 100
	// OLD CODE: estimatedBlock = 100 - 250 = UNDERFLOW!
	// NEW CODE: estimatedBlock = 1 (clamped)

	result, err := indexer.getBlockByTimestamp(context.Background(), 0)

	assert.NoError(t, err)
	assert.GreaterOrEqual(t, result, uint64(1), "Result should be >= 1")
	assert.LessOrEqual(t, result, uint64(100), "Result should be <= latestBlock")

	// Specifically check it's not the underflow value
	// If uint64 underflows: 100 - 250 = 18446744073709551466
	assert.Less(t, result, uint64(1000), "Should not underflow to max uint64 range")
}

func Test_getBlockByTimestamp_EdgeCases(t *testing.T) {
	t.Run("targetTimestamp greater than latest", func(t *testing.T) {
		mockClient := &mockEthClientWithBlocks{
			blocks: map[uint64]*types.Header{
				1: {
					Number: big.NewInt(1),
					Time:   0,
				},
				1000: {
					Number: big.NewInt(1000),
					Time:   11988,
				},
			},
			latest: 1000,
		}

		indexer := &Indexer{
			srcEthClient: mockClient,
			ctx:          context.Background(),
		}

		// Target in the future should return latest block
		result, err := indexer.getBlockByTimestamp(context.Background(), 20000)

		assert.NoError(t, err)
		assert.Equal(t, uint64(1000), result, "Should return latest block for future timestamp")
	})

	t.Run("exact block match", func(t *testing.T) {
		mockClient := &mockEthClientWithBlocks{
			blocks: map[uint64]*types.Header{
				1: {
					Number: big.NewInt(1),
					Time:   0,
				},
				1000: {
					Number: big.NewInt(1000),
					Time:   11988,
				},
			},
			latest: 1000,
		}

		indexer := &Indexer{
			srcEthClient: mockClient,
			ctx:          context.Background(),
		}

		// Target exactly at genesis
		result, err := indexer.getBlockByTimestamp(context.Background(), 0)

		assert.NoError(t, err)
		assert.Equal(t, uint64(1), result, "Should return block 1 for genesis timestamp")
	})
}
