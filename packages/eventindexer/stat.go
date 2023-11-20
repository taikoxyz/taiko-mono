package eventindexer

import (
	"context"
	"math/big"
)

var (
	StatTypeProofTime   = "proofTime"
	StatTypeProofReward = "proofReward"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Stat struct {
	ID                 int    `json:"id"`
	AverageProofTime   string `json:"averageProofTime"`
	AverageProofReward string `json:"averageProofReward"`
	NumProofs          uint64 `json:"numProofs"`
	NumBlocksAssigned  uint64 `json:"numBlocksAssigned"`
	FeeTokenAddress    string `json:"feeTokenAddress"`
	StatType           string `json:"statType"`
}

// SaveStatOpts
type SaveStatOpts struct {
	ProofTime       *big.Int
	ProofReward     *big.Int
	FeeTokenAddress *string
	StatType        string
}

// StatRepository is used to interact with stats in the store
type StatRepository interface {
	Save(ctx context.Context, opts SaveStatOpts) (*Stat, error)
	Find(ctx context.Context, statType string, feeTokenAddress *string) (*Stat, error)
	FindAll(ctx context.Context) ([]*Stat, error)
}
