package watchdog

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"testing"

	cybererrors "github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
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

	assert.Equal(t, "1-2-MessageProcessed-queue", w.queueName())
}

func TestShouldRequeueCheckMessageErrorReturnsFalseForMalformedJSON(t *testing.T) {
	var syntaxErr *json.SyntaxError

	err := json.Unmarshal([]byte("{"), &struct{}{})
	assert.True(t, errors.As(err, &syntaxErr))

	assert.False(t, shouldRequeueCheckMessageError(cybererrors.Wrap(err, "json.Unmarshal")))
}

func TestPauseBridgeSendsPauseFromPauser(t *testing.T) {
	pauser := common.HexToAddress("0x123")
	bridgeAddress := common.HexToAddress("0x456")
	mgr := &mock.TxManager{
		FromAddress: pauser,
		Receipt:     &types.Receipt{Status: types.ReceiptStatusSuccessful},
	}

	receipt, err := new(Watchdog).pauseBridge(
		context.Background(),
		&mock.Bridge{PauserAddress: pauser},
		bridgeAddress,
		mgr,
	)
	assert.NoError(t, err)
	assert.Equal(t, types.ReceiptStatusSuccessful, receipt.Status)
	assert.True(t, mgr.Sent)
	assert.Equal(t, &bridgeAddress, mgr.Candidate.To)

	pauseCalldata, err := encoding.BridgeABI.Pack("pause")
	assert.NoError(t, err)
	assert.Equal(t, pauseCalldata, mgr.Candidate.TxData)
}

func TestPauseBridgeRejectsNonPauserTxSender(t *testing.T) {
	mgr := &mock.TxManager{FromAddress: common.HexToAddress("0x123")}

	receipt, err := new(Watchdog).pauseBridge(
		context.Background(),
		&mock.Bridge{PauserAddress: common.HexToAddress("0x456")},
		common.HexToAddress("0x789"),
		mgr,
	)
	assert.ErrorContains(t, err, "does not match bridge pauser")
	assert.Nil(t, receipt)
	assert.False(t, mgr.Sent)
}
