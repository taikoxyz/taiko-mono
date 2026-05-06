package watchdog

import (
	"encoding/json"
	"errors"
	"math/big"
	"testing"

	cybererrors "github.com/cyberhorsey/errors"
	"github.com/stretchr/testify/assert"
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
