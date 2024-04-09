package eventindexer

import (
	"context"
	"database/sql"
	"math/big"
	"net/http"
	"time"

	"github.com/morkid/paginate"
	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
)

var (
	EventNameTransitionProved    = "TransitionProved"
	EventNameTransitionContested = "TransitionContested"
	EventNameBlockProposed       = "BlockProposed"
	EventNameBlockAssigned       = "BlockAssigned"
	EventNameBlockVerified       = "BlockVerified"
	EventNameMessageSent         = "MessageSent"
	EventNameSwap                = "Swap"
	EventNameMint                = "Mint"
	EventNameNFTTransfer         = "Transfer"
	EventNameInstanceAdded       = "InstanceAdded"
)

// Event represents a stored EVM event. The fields will be serialized
// into the Data field to be unmarshalled into a concrete struct
// dependant on the name of the event
type Event struct {
	ID              int                 `json:"id"`
	Name            string              `json:"name"`
	Data            datatypes.JSON      `json:"data"`
	ChainID         int64               `json:"chainID"`
	Event           string              `json:"event"`
	Address         string              `json:"address"`
	BlockID         sql.NullInt64       `json:"blockID"`
	Amount          decimal.NullDecimal `json:"amount"`
	ProofReward     decimal.NullDecimal `json:"proofReward"`
	ProposerReward  decimal.NullDecimal `json:"proposerReward"`
	AssignedProver  string              `json:"assignedProver"`
	To              string              `json:"to"`
	TokenID         sql.NullInt64       `json:"tokenID"`
	ContractAddress string              `json:"contractAddress"`
	FeeTokenAddress string              `json:"feeTokenAddress"`
	TransactedAt    time.Time           `json:"transactedAt"`
	Tier            sql.NullInt16       `json:"tier"`
	EmittedBlockID  uint64              `json:"emittedBlockID"`
}

// SaveEventOpts
type SaveEventOpts struct {
	Name            string
	Data            string
	ChainID         *big.Int
	Event           string
	Address         string
	BlockID         *int64
	Amount          *big.Int
	ProposerReward  *big.Int
	ProofReward     *big.Int
	AssignedProver  *string
	To              *string
	TokenID         *int64
	ContractAddress *string
	FeeTokenAddress *string
	TransactedAt    time.Time
	Tier            *uint16
	EmittedBlockID  uint64
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
	FindByEventTypeAndBlockID(
		ctx context.Context,
		eventType string,
		blockID int64) (*Event, error)
	Delete(
		ctx context.Context,
		id int,
	) error
	GetCountByAddressAndEventName(ctx context.Context, address string, event string) (int, error)
	GetByAddressAndEventName(
		ctx context.Context,
		req *http.Request,
		address string,
		event string,
	) (paginate.Page, error)
	FirstByAddressAndEventName(
		ctx context.Context,
		address string,
		event string,
	) (*Event, error)
	GetAssignedBlocksByProverAddress(
		ctx context.Context,
		req *http.Request,
		address string,
	) (paginate.Page, error)
	DeleteAllAfterBlockID(blockID uint64, srcChainID uint64) error
	FindLatestBlockID(
		srcChainID uint64,
	) (uint64, error)
}
