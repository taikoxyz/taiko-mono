package processor

import (
	"context"
	"errors"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_waitForConfirmations(t *testing.T) {
	p := newTestProcessor(true)

	err := p.waitForConfirmations(context.TODO(), mock.SucceedTxHash)
	assert.Nil(t, err)
}

// receiptErrClient fails the receipt lookup outright, as a node that is down would.
type receiptErrClient struct {
	mock.EthClient
	err error
}

func (c *receiptErrClient) TransactionReceipt(
	_ context.Context,
	_ common.Hash,
) (*types.Receipt, error) {
	return nil, c.err
}

func Test_waitForConfirmationsReturnsReceiptErrors(t *testing.T) {
	p := newTestProcessor(true)
	p.srcEthClient = &receiptErrClient{err: errors.New("dial tcp: connect: connection refused")}

	// ethereum.NotFound and "still waiting" are the two the wait swallows; anything else is a
	// broken client and has to surface rather than be waited out.
	err := p.waitForConfirmations(context.Background(), mock.SucceedTxHash)

	assert.ErrorContains(t, err, "connection refused")
}

func Test_waitForConfirmationsRespectsItsTimeout(t *testing.T) {
	p := newTestProcessor(true)
	p.confTimeoutInSeconds = 0

	// The wait is bounded by confTimeoutInSeconds, so a transaction that never gathers its
	// confirmations gives the queue back its message instead of pinning a worker forever.
	err := p.waitForConfirmations(context.Background(), mock.NotFoundTxHash)

	assert.ErrorIs(t, err, context.DeadlineExceeded)
}
