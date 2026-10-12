package eventindexer

import "context"

// NFTCursorRepository maintains the last completed NFT batch and reads the legacy
// watermark only when no NFT checkpoint exists. Writers must use the locked session.
type NFTCursorRepository interface {
	FindLatestBlockID(context.Context, uint64) (uint64, error)
	FindCheckpoint(context.Context, uint64) (uint64, bool, error)
	SaveCheckpoint(context.Context, uint64, uint64) error
}
