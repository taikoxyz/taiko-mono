package encoding

import (
	"crypto/rand"

	"github.com/ethereum/go-ethereum/log"
)

// randomBytes generates a random bytes.
func randomBytes(size int) (b []byte) {
	b = make([]byte, size)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Generate random bytes error", "error", err)
	}
	return
}
