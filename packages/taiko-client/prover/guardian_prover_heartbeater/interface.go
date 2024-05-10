package guardianproverheartbeater

import (
	"context"
	"math/big"
)

// BlockSigner defines an interface that communicates with a central Guardian Prover server, sending signed blocks.
type BlockSigner interface {
	SignAndSendBlock(ctx context.Context, blockID *big.Int) error
	SendStartupMessage(
		ctx context.Context,
		revision string,
		version string,
		l1NodeVersion string,
		l2NodeVersion string,
	) error
}

// Heartbeater defines an interface that communicates with a central Guardian Prover server, sending heartbeats.
type Heartbeater interface {
	SendHeartbeat(ctx context.Context, latestL1Block uint64, latestL2Block uint64) error
}

// BlockSenderHeartbeater defines an interface that communicates with a central Guardian Prover server,
// sending heartbeats and signed blocks (and in the future, contested blocks).
type BlockSenderHeartbeater interface {
	BlockSigner
	Heartbeater
}
