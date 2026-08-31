package repo

import (
	"fmt"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// testRef returns a distinct TransferLogRef per n, standing in for the
// (txHash, logIndex) identity a real log carries. Two calls with the same n
// represent the same log being applied twice, which is what a restart replay
// does.
func testRef(kind string, n uint) eventindexer.TransferLogRef {
	return eventindexer.TransferLogRef{
		ChainID:  1,
		TxHash:   fmt.Sprintf("0x%064x", n),
		LogIndex: n,
		Kind:     kind,
	}
}
