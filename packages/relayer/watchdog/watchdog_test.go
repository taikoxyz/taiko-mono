package watchdog

import (
	"encoding/json"
	"errors"
	"math/big"
	"testing"

	cybererrors "github.com/cyberhorsey/errors"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
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

// When the destination bridge never sent a processed message (i.e. a forged
// message), the watchdog must NOT attempt to pause (it is not the pauser) and
// it must acknowledge the message (return nil) so it is not requeued into an
// endless loop. Detection alerting (BridgeMessageNotSent) is preserved in the
// implementation.
func Test_checkMessage_notSent_acksWithoutPausing(t *testing.T) {
	w := &Watchdog{
		srcBridge:  &mock.Bridge{},
		destBridge: &mock.Bridge{}, // mock IsMessageSent returns false
		cfg:        &Config{},
	}

	body, err := json.Marshal(queue.QueueMessageProcessedBody{
		ID:      1,
		Message: bridge.IBridgeMessage{Id: 5},
	})
	assert.Nil(t, err)

	// A forged message (never sent by the dest bridge) must be acknowledged
	// (nil error => not requeued) instead of erroring and looping forever. The
	// watchdog is not the pauser, so it never attempts a pause transaction.
	err = w.checkMessage(queue.Message{Body: body})
	assert.Nil(t, err)
}
