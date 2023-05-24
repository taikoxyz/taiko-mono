package eventindexer

import (
	"context"
	"math/big"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Stat struct {
	ChainID          *big.Int `json:"chainID"`
	AverageProofTime uint64   `json:"averageProofTime"`
	NumProofs        uint64   `json:"numProofs"`
}

// SaveStatOpts
type SaveStatOpts struct {
	ChainID   *big.Int
	ProofTime uint64
}

// StatRepository is used to interact with stats in the store
type Statepository interface {
	Save(ctx context.Context, opts SaveEventOpts) (*Event, error)
	FindByChainID(ctx context.Context, chainID *big.Int) (*Stat, error)
}
