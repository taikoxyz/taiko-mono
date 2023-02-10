package relayer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"gorm.io/datatypes"
)

var (
	EventNameMessageSent = "MessageSent"
)

// EventStatus is used to indicate whether processing has been attempted
// for this particular event, and it's success
type EventStatus int

const (
	EventStatusNew EventStatus = iota
	EventStatusRetriable
	EventStatusDone
	EventStatusNewOnlyOwner
)

type EventType int

const (
	EventTypeSendETH EventType = iota
	EventTypeSendERC20
)

// String returns string representation of an event status for logging
func (e EventStatus) String() string {
	return [...]string{"new", "retriable", "done", "onlyOwner"}[e]
}

func (e EventType) String() string {
	return [...]string{"sendETH", "sendERC20"}[e]
}

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Event struct {
	ID                     int            `json:"id"`
	Name                   string         `json:"name"`
	Data                   datatypes.JSON `json:"data"`
	Status                 EventStatus    `json:"status"`
	EventType              EventType      `json:"eventType"`
	ChainID                int64          `json:"chainID"`
	CanonicalTokenAddress  string         `json:"canonicalTokenAddress"`
	CanonicalTokenSymbol   string         `json:"canonicalTokenSymbol"`
	CanonicalTokenName     string         `json:"canonicalTokenName"`
	CanonicalTokenDecimals uint8          `json:"canonicalTokenDecimals"`
	Amount                 string         `json:"amount"`
}

// SaveEventOpts
type SaveEventOpts struct {
	Name                   string
	Data                   string
	ChainID                *big.Int
	Status                 EventStatus
	EventType              EventType
	CanonicalTokenAddress  string
	CanonicalTokenSymbol   string
	CanonicalTokenName     string
	CanonicalTokenDecimals uint8
	Amount                 string
}

// EventRepository is used to interact with events in the store
type EventRepository interface {
	Save(ctx context.Context, opts SaveEventOpts) (*Event, error)
	UpdateStatus(ctx context.Context, id int, status EventStatus) error
	FindAllByAddressAndChainID(
		ctx context.Context,
		chainID *big.Int,
		address common.Address,
	) ([]*Event, error)
	FindAllByAddress(
		ctx context.Context,
		address common.Address,
	) ([]*Event, error)
}
