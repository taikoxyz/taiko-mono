package watchdog

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_Name(t *testing.T) {
	w := Watchdog{}

	assert.Equal(t, "watchdog", w.Name())
}

func Test_queueName(t *testing.T) {
	w := Watchdog{
		srcChainId:  big.NewInt(1),
		destChainId: big.NewInt(2),
	}

	assert.Equal(t, "1-2-MessageReceived-queue", w.queueName())
}

func Test_setLatestNonce(t *testing.T) {
	w := Watchdog{
		destNonce: 0,
	}

	w.setLatestNonce(100)

	assert.Equal(t, w.destNonce, uint64(100))
}

func Test_getLatestNonce(t *testing.T) {
	w := Watchdog{
		destEthClient: &mock.EthClient{},
	}

	auth := &bind.TransactOpts{}

	err := w.getLatestNonce(context.Background(), auth)

	assert.Nil(t, err)

	assert.Equal(t, auth.Nonce, new(big.Int).SetUint64(mock.PendingNonce))

	assert.Equal(t, w.destNonce, mock.PendingNonce)
}
