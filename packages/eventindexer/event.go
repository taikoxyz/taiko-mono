package eventindexer

import (
	"context"
	"math/big"

	"gorm.io/datatypes"
)

var (
	EventNameBlockProven   = "BlockProven"
	EventNameBlockProposed = "BlockProposed"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Event struct {
	ID      int            `json:"id"`
	Name    string         `json:"name"`
	Data    datatypes.JSON `json:"data"`
	ChainID int64          `json:"chainID"`
	Event   string         `json:"event"`
	Address string         `json:"address"`
}

// SaveEventOpts
type SaveEventOpts struct {
	Name    string
	Data    string
	ChainID *big.Int
	Event   string
	Address string
}

type UniqueProversResponse struct {
	Address string `json:"address"`
	Count   int    `json:"count"`
}

type UniqueProposersResponse struct {
	Address string `json:"address"`
	Count   int    `json:"count"`
}

// EventRepository is used to interact with events in the store
type EventRepository interface {
	Save(ctx context.Context, opts SaveEventOpts) (*Event, error)
	FindUniqueProvers(
		ctx context.Context,
	) ([]UniqueProversResponse, error)
	FindUniqueProposers(
		ctx context.Context,
	) ([]UniqueProposersResponse, error)
	GetCountByAddressAndEventName(ctx context.Context, address string, event string) (int, error)
}
