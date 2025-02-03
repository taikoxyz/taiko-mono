package txlistfetcher

import (
	"fmt"
	"math/big"
)

// sliceTxList returns the sliced txList bytes from the given offset and length.
func sliceTxList(id *big.Int, b []byte, offset, length uint32) ([]byte, error) {
	if offset+length > uint32(len(b)) {
		return nil, fmt.Errorf(
			"invalid txlist offset and size in metadata (%d): offset=%d, size=%d, blobSize=%d", id, offset, length, len(b),
		)
	}
	return b[offset : offset+length], nil
}
