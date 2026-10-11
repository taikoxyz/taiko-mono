package eventindexer

import "context"

// NFTCursorRepository reads the legacy event watermark used by NFT startup.
// It does not write events or provide event-query APIs.
type NFTCursorRepository interface {
	FindLatestBlockID(context.Context, uint64) (uint64, error)
}
