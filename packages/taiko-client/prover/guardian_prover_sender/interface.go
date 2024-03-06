package guardianproversender

import (
	"context"
	"math/big"
)

type BlockSigner interface {
	SignAndSendBlock(ctx context.Context, blockID *big.Int) error
	SendStartup(
		ctx context.Context,
		revision string,
		version string,
		l1NodeVersion string,
		l2NodeVersion string,
	) error
}

type Heartbeater interface {
	SendHeartbeat(ctx context.Context, latestL1Block uint64, latestL2Block uint64) error
}

// BlockSenderHeartbeater defines an interface that communicates with a central Guardian Prover server,
// sending heartbeats and signed blocks (and in the future, contested blocks).
type BlockSenderHeartbeater interface {
	BlockSigner
	Heartbeater
	Close() error
}
