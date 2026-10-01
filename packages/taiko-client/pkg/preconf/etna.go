package preconf

import (
	"errors"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ErrNotSupportedAfterEtna is returned for preconfirmation blocks at or after the Etna fork. Etna removes
// the anchor transaction that preconfirmation blocks are still built and validated around, so these
// blocks are rejected until preconfirmation supports Etna.
var ErrNotSupportedAfterEtna = errors.New("preconfirmation is not supported after Etna yet")

// CheckNotEtna returns ErrNotSupportedAfterEtna when the block timestamp is at or after Etna on chainID.
func CheckNotEtna(chainID *big.Int, timestamp uint64) error {
	if rpc.IsEtna(chainID, timestamp) {
		return ErrNotSupportedAfterEtna
	}
	return nil
}
