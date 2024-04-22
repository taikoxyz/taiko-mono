package relayer

import (
	"context"
	"math/big"
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/morkid/paginate"
	"gorm.io/datatypes"
)

var (
	EventNameMessageSent          = "MessageSent"
	EventNameMessageStatusChanged = "MessageStatusChanged"
	EventNameMessageProcessed     = "MessageProcessed"
	EventNameChainDataSynced      = "ChainDataSynced"
)

// EventStatus is used to indicate whether processing has been attempted
// for this particular event, and it's success
type EventStatus int

const (
	EventStatusNew EventStatus = iota
	EventStatusRetriable
	EventStatusDone
	EventStatusFailed
	EventStatusRecalled
)

type EventType int

const (
	EventTypeSendETH EventType = iota
	EventTypeSendERC20
	EventTypeSendERC721
	EventTypeSendERC1155
)

// String returns string representation of an event status for logging
func (e EventStatus) String() string {
	return [...]string{"new", "retriable", "done", "failed", "recalled"}[e]
}

func (e EventType) String() string {
	return [...]string{"sendETH", "sendERC20", "sendERC721", "sendERC1155"}[e]
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
	DestChainID            int64          `json:"destChainID"`
	SyncedChainID          uint64         `json:"syncedChainID"`
	EmittedBlockID         uint64         `json:"emittedBlockID"`
	BlockID                uint64         `json:"blockID"`
	SyncedInBlockID        uint64         `json:"syncedInBlockID"`
	SyncData               string         `json:"syncData"`
	Kind                   string         `json:"kind"`
	CanonicalTokenAddress  string         `json:"canonicalTokenAddress"`
	CanonicalTokenSymbol   string         `json:"canonicalTokenSymbol"`
	CanonicalTokenName     string         `json:"canonicalTokenName"`
	CanonicalTokenDecimals uint8          `json:"canonicalTokenDecimals"`
	Amount                 string         `json:"amount"`
	MsgHash                string         `json:"msgHash"`
	MessageOwner           string         `json:"messageOwner"`
	Event                  string         `json:"event"`
}

// SaveEventOpts
type SaveEventOpts struct {
	Name                   string
	Data                   string
	ChainID                *big.Int
	DestChainID            *big.Int
	Status                 EventStatus
	EventType              EventType
	CanonicalTokenAddress  string
	CanonicalTokenSymbol   string
	CanonicalTokenName     string
	CanonicalTokenDecimals uint8
	Amount                 string
	MsgHash                string
	MessageOwner           string
	Event                  string
	SyncedChainID          uint64
	BlockID                uint64
	EmittedBlockID         uint64
	SyncData               string
	Kind                   string
	SyncedInBlockID        uint64
}

type FindAllByAddressOpts struct {
	Address   common.Address
	EventType *EventType
	Event     *string
	MsgHash   *string
	ChainID   *big.Int
}

// EventRepository is used to interact with events in the store
type EventRepository interface {
	Save(ctx context.Context, opts SaveEventOpts) (*Event, error)
	UpdateStatus(ctx context.Context, id int, status EventStatus) error
	FindAllByAddress(
		ctx context.Context,
		req *http.Request,
		opts FindAllByAddressOpts,
	) (paginate.Page, error)
	FirstByMsgHash(
		ctx context.Context,
		msgHash string,
	) (*Event, error)
	FirstByEventAndMsgHash(
		ctx context.Context,
		event string,
		msgHash string,
	) (*Event, error)
	Delete(ctx context.Context, id int) error
	ChainDataSyncedEventByBlockNumberOrGreater(
		ctx context.Context,
		srcChainId uint64,
		syncedChainId uint64,
		blockNumber uint64,
	) (*Event, error)
	LatestChainDataSyncedEvent(
		ctx context.Context,
		srcChainId uint64,
		syncedChainId uint64,
	) (uint64, error)
	DeleteAllAfterBlockID(blockID uint64, srcChainID uint64, destChainID uint64) error
	FindLatestBlockID(
		event string,
		srcChainID uint64,
		destChainID uint64,
	) (uint64, error)
}
