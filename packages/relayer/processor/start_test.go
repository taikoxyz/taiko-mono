package processor

import (
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestStart_TargetTxHashReturnsProcessSingleError(t *testing.T) {
	p := newTestProcessor(false)

	txHash := mock.NotFoundTxHash
	p.targetTxHash = &txHash

	err := p.Start()

	assert.ErrorIs(t, err, ethereum.NotFound)
}

func TestWaitForInterrupt(t *testing.T) {
	p := newTestProcessor(false)
	assert.True(t, p.WaitForInterrupt())

	txHash := mock.SucceedTxHash
	p.targetTxHash = &txHash
	assert.False(t, p.WaitForInterrupt())
}
