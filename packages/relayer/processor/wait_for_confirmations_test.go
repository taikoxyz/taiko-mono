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

// countingEthClient records how many receipt lookups the wait made.
type countingEthClient struct {
	mock.EthClient
	receiptCalls int
}

func (c *countingEthClient) TransactionReceipt(
	ctx context.Context,
	txHash common.Hash,
) (*types.Receipt, error) {
	c.receiptCalls++

	return c.EthClient.TransactionReceipt(ctx, txHash)
}

// Test_waitForConfirmationsReturnsWithoutPolling guards against reintroducing a stall for a
// transaction that is already confirmed. Exactly one receipt lookup proves the wait returned on
// its first check instead of falling through to the poll loop and sleeping until its first tick.
func Test_waitForConfirmationsReturnsWithoutPolling(t *testing.T) {
	p := newTestProcessor(true)

	client := &countingEthClient{}
	p.srcEthClient = client

	err := p.waitForConfirmations(context.Background(), mock.SucceedTxHash)

	assert.Nil(t, err)
	assert.Equal(t, 1, client.receiptCalls)
}

// Test_waitForConfirmationsDoesNotReturnEarlyWithoutConfirmations is the counterpart to the test
// above: that first check may only short circuit when the confirmations are actually satisfied,
// never unconditionally.
func Test_waitForConfirmationsDoesNotReturnEarlyWithoutConfirmations(t *testing.T) {
	p := newTestProcessor(true)
	p.confTimeoutInSeconds = 0
	// the mock receipt sits one block behind the latest block, so requiring more confirmations
	// than there are blocks can never be satisfied.
	p.confirmations = uint64(mock.BlockNum) + 1

	err := p.waitForConfirmations(context.Background(), mock.SucceedTxHash)

	assert.ErrorIs(t, err, context.DeadlineExceeded)
}

// Test_waitForConfirmationsReturnsWhenContextIsCanceled asserts a cancelled caller context
// unblocks the wait.
func Test_waitForConfirmationsReturnsWhenContextIsCanceled(t *testing.T) {
	p := newTestProcessor(true)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	err := p.waitForConfirmations(ctx, mock.NotFoundTxHash)

	assert.ErrorIs(t, err, context.Canceled)
}
