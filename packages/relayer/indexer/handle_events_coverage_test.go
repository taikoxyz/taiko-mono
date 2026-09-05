package indexer

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	signalservice "github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

// newCheckpointTestService builds an indexer with a repository the test can inspect and the
// config the checkpoint handler dereferences for its confirmation timeout.
func newCheckpointTestService(t *testing.T) (*Indexer, *mock.EventRepository) {
	t.Helper()

	i, _ := newTestService(Sync, Filter)
	repo := mock.NewEventRepository()
	i.eventRepo = repo
	i.cfg = &Config{ConfirmationTimeout: time.Second}
	i.confirmations = 1

	return i, repo
}

func checkpointSavedEvent() *signalservice.SignalServiceCheckpointSaved {
	return &signalservice.SignalServiceCheckpointSaved{
		BlockNumber: big.NewInt(42),
		BlockHash:   [32]byte{0x01},
		StateRoot:   [32]byte{0x02},
		Raw: types.Log{
			TxHash:      mock.SucceedTxHash,
			BlockNumber: 7,
		},
	}
}

func TestHandleCheckpointSavedEventSavesTheCheckpoint(t *testing.T) {
	i, repo := newCheckpointTestService(t)

	before := testutil.ToFloat64(relayer.CheckpointSavedEventsIndexed)

	require.NoError(t, i.handleCheckpointSavedEvent(context.Background(), checkpointSavedEvent(), false))

	// The processor waits on these rows before it can prove a message, so the checkpoint has to
	// be persisted with the synced block it represents. A row count cannot see that: rewriting the
	// handler to persist zeroes for all of it left this test, and the whole package, green.
	require.Equal(t, 1, repo.SavedCount())

	saved := repo.SavedEvents()[0]

	event := checkpointSavedEvent()

	assert.Equal(t, event.BlockNumber.Uint64(), saved.BlockID,
		"the synced block is what wait_header_synced gates every claim on")
	assert.Equal(t, event.Raw.BlockNumber, saved.EmittedBlockID)
	assert.Equal(t, event.Raw.BlockNumber, saved.SyncedInBlockID)
	assert.Equal(t, common.Hash(event.StateRoot).Hex(), saved.SyncData)
	assert.Equal(t, i.destChainId.Uint64(), saved.SyncedChainID,
		"both reader queries filter on this, so a zero here is a row that is never found")
	assert.Equal(t, relayer.EventNameCheckpointSaved, saved.Name)

	assert.Equal(t, float64(1), testutil.ToFloat64(relayer.CheckpointSavedEventsIndexed)-before)
}

func TestHandleCheckpointSavedEventSkipsRemovedEvents(t *testing.T) {
	i, repo := newCheckpointTestService(t)

	event := checkpointSavedEvent()
	event.Raw.Removed = true

	require.NoError(t, i.handleCheckpointSavedEvent(context.Background(), event, false))

	// A removed log came from a reorged-out block. Saving it would have the processor prove
	// against a state root that is no longer canonical.
	assert.Equal(t, 0, repo.SavedCount())
}

func TestHandleCheckpointSavedEventWaitsForConfirmationsWhenAsked(t *testing.T) {
	i, repo := newCheckpointTestService(t)

	require.NoError(t, i.handleCheckpointSavedEvent(context.Background(), checkpointSavedEvent(), true))

	assert.Equal(t, 1, repo.SavedCount())
}

func TestHandleCheckpointSavedEventReturnsConfirmationErrors(t *testing.T) {
	i, repo := newCheckpointTestService(t)
	// More confirmations than there are blocks can never be satisfied, so the wait runs out.
	i.confirmations = uint64(mock.BlockNum) + 1
	i.cfg = &Config{ConfirmationTimeout: 50 * time.Millisecond}

	err := i.handleCheckpointSavedEvent(context.Background(), checkpointSavedEvent(), true)

	// Saving a checkpoint whose transaction never reached the required depth would let the
	// processor prove against a block that could still be reorged away.
	require.Error(t, err)
	assert.Equal(t, 0, repo.SavedCount())
}

func statusChangedEvent(msgHash [32]byte) *bridge.BridgeMessageStatusChanged {
	return &bridge.BridgeMessageStatusChanged{
		MsgHash: msgHash,
		Status:  uint8(relayer.EventStatusDone),
		Raw:     types.Log{BlockNumber: 11},
	}
}

func TestHandleMessageStatusChangedEventSkipsUnknownMessages(t *testing.T) {
	i, _ := newTestService(Sync, Filter)
	repo := mock.NewEventRepository()
	i.eventRepo = repo

	err := i.handleMessageStatusChangedEvent(
		context.Background(),
		mock.MockChainID,
		statusChangedEvent([32]byte{0xff}),
	)

	// Without a prior MessageSent there is no owner to attribute the status to, and a row with an
	// empty owner is worse than no row: the API indexes these by address.
	require.NoError(t, err)
	assert.Equal(t, 0, repo.SavedCount())
}

func TestHandleMessageStatusChangedEventRecordsTheStatus(t *testing.T) {
	i, _ := newTestService(Sync, Filter)
	repo := mock.NewEventRepository()
	i.eventRepo = repo

	var msgHash [32]byte

	msgHash[0] = 0xab

	owner := common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6")

	// The prior MessageSent is what carries the owner forward onto the status row.
	_, err := repo.Save(context.Background(), &relayer.SaveEventOpts{
		Name:         relayer.EventNameMessageSent,
		Event:        relayer.EventNameMessageSent,
		Data:         "{}",
		ChainID:      mock.MockChainID,
		DestChainID:  mock.MockChainID,
		MsgHash:      common.Hash(msgHash).Hex(),
		MessageOwner: owner.Hex(),
	})
	require.NoError(t, err)

	before := testutil.ToFloat64(relayer.MessageStatusChangedEventsIndexed)

	require.NoError(t, i.handleMessageStatusChangedEvent(
		context.Background(),
		mock.MockChainID,
		statusChangedEvent(msgHash),
	))

	require.Equal(t, 2, repo.SavedCount())

	saved, err := repo.FirstByEventAndMsgHash(
		context.Background(),
		relayer.EventNameMessageStatusChanged,
		common.Hash(msgHash).Hex(),
	)

	require.NoError(t, err)
	require.NotNil(t, saved)
	assert.Equal(t, owner.Hex(), saved.MessageOwner, "the owner has to carry over from MessageSent")
	assert.Equal(t, relayer.EventStatusDone, saved.Status)
	assert.Equal(t, float64(1),
		testutil.ToFloat64(relayer.MessageStatusChangedEventsIndexed)-before)
}

func TestIndexerName(t *testing.T) {
	assert.Equal(t, "indexer", new(Indexer).Name())
}
