package encoding

import (
	"crypto/rand"
	"testing"

	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"gopkg.in/go-playground/assert.v1"
)

// randomBytes generates a random bytes.
func randomBytes(size int) (b []byte) {
	b = make([]byte, size)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Generate random bytes error", "error", err)
	}

	return
}

func Test_logsBloomToBytes(t *testing.T) {
	testLogsBloom := types.BytesToBloom(randomBytes(256))
	bloom := logsBloomToBytes(testLogsBloom)
	index := 0

	for _, b := range bloom {
		assert.Equal(t, hexutil.Encode(testLogsBloom[index:index+32]), hexutil.Encode(b[:]))
		index += 32
	}
}
