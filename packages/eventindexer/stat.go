package eventindexer

import (
	"context"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Stat struct {
	ID                 int    `json:"id"`
	AverageProofTime   uint64 `json:"averageProofTime"`
	AverageProofReward uint64 `json:"averageProofReward"`
	NumProofs          uint64 `json:"numProofs"`
}

// SaveStatOpts
type SaveStatOpts struct {
	ProofTime   *uint64
	ProofReward *uint64
}

// StatRepository is used to interact with stats in the store
type StatRepository interface {
	Save(ctx context.Context, opts SaveStatOpts) (*Stat, error)
	Find(ctx context.Context) (*Stat, error)
}
