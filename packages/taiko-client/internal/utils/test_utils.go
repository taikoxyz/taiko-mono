package utils

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/assert"
)

// MineL1Block mines a block on the L1 chain.
func MineL1Block(t *testing.T, l1Client *rpc.Client) {
	var blockID string
	assert.Nil(t, l1Client.CallContext(context.Background(), &blockID, "evm_mine"))
	assert.NotEmpty(t, blockID)
}
