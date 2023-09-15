package eventindexer

import (
	"context"
	"math/big"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Stat struct {
	ID                    int    `json:"id"`
	AverageProofTime      string `json:"averageProofTime"`
	AverageProofReward    string `json:"averageProofReward"`
	AverageProposerReward string `json:"averageProposerReward"`
	NumProposerRewards    uint64 `json:"numProposerRewards"`
	NumProofs             uint64 `json:"numProofs"`
	NumVerifiedBlocks     uint64 `json:"numVerifiedBlocks"`
}

// SaveStatOpts
type SaveStatOpts struct {
	ProofTime      *big.Int
	ProofReward    *big.Int
	ProposerReward *big.Int
}

// StatRepository is used to interact with stats in the store
type StatRepository interface {
	Save(ctx context.Context, opts SaveStatOpts) (*Stat, error)
	Find(ctx context.Context) (*Stat, error)
}
