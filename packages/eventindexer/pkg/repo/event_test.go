package repo

import (
	"context"
	"fmt"
	"math/big"
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
)

var (
	blockID             int64 = 1
	dummyProveEventOpts       = eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameTransitionProved,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameTransitionProved,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	}
	dummyProposeEventOpts = eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBlockProposed,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBlockProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	}
	dummyShastaProvedEventOpts = eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameProved,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameProved,
		ChainID:      big.NewInt(1),
		TransactedAt: time.Now(),
	}
	dummyShastaProposedEventOpts = eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameProposed,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameProposed,
		ChainID:      big.NewInt(1),
		TransactedAt: time.Now(),
	}
)

func TestIntegration_Event_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    eventindexer.SaveEventOpts
		wantErr error
	}{
		{
			"success",
			eventindexer.SaveEventOpts{
				Name:         "test",
				ChainID:      big.NewInt(1),
				Data:         "{\"data\":\"something\"}",
				Event:        eventindexer.EventNameBlockProposed,
				Address:      "0x123",
				TransactedAt: time.Now(),
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err = eventRepo.Save(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Event_FindUniqueProvers_MultipleAddresses(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	addr1 := "0xaaaa"
	addr2 := "0xbbbb"

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameTransitionProved,
		Address:      addr1,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameTransitionProved,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBatchesProven,
		Address:      addr1,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBatchesProven,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameTransitionProved,
		Address:      addr2,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameTransitionProved,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	resp, err := eventRepo.FindUniqueProvers(context.Background())
	assert.Equal(t, nil, err)

	expected := map[string]int{
		addr1: 2,
		addr2: 1,
	}

	assert.Equal(t, len(expected), len(resp))

	actual := make(map[string]int)
	for _, v := range resp {
		actual[v.Address] = v.Count
	}

	assert.Equal(t, expected, actual)
}

func TestIntegration_Event_FindUniqueProposers_MultipleAddresses(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	addr1 := "0xcccc"
	addr2 := "0xdddd"

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBlockProposed,
		Address:      addr1,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBlockProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBatchProposed,
		Address:      addr1,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBatchProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBlockProposed,
		Address:      addr2,
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBlockProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	resp, err := eventRepo.FindUniqueProposers(context.Background())
	assert.Equal(t, nil, err)

	expected := map[string]int{
		addr1: 2,
		addr2: 1,
	}

	assert.Equal(t, len(expected), len(resp))

	actual := make(map[string]int)
	for _, v := range resp {
		actual[v.Address] = v.Count
	}

	assert.Equal(t, expected, actual)
}

func TestIntegration_Event_FindUniqueProvers(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProveEventOpts)

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProposeEventOpts)

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyShastaProvedEventOpts)

	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		wantResp []eventindexer.UniqueProversResponse
		wantErr  error
	}{
		{
			"success",
			[]eventindexer.UniqueProversResponse{
				{
					Address: "0x123",
					Count:   2,
				},
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.FindUniqueProvers(context.Background())
			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, len(tt.wantResp), len(resp))

			for k, v := range resp {
				assert.Equal(t, tt.wantResp[k].Address, v.Address)
				assert.Equal(t, tt.wantResp[k].Count, v.Count)
			}
		})
	}
}

func TestIntegration_Event_FindUniqueProposers(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProveEventOpts)

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProposeEventOpts)

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyShastaProposedEventOpts)

	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		wantResp []eventindexer.UniqueProposersResponse
		wantErr  error
	}{
		{
			"success",
			[]eventindexer.UniqueProposersResponse{
				{
					Address: dummyProposeEventOpts.Address,
					Count:   2,
				},
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.FindUniqueProposers(context.Background())
			spew.Dump(resp)
			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, len(tt.wantResp), len(resp))

			for k, v := range resp {
				assert.Equal(t, tt.wantResp[k].Address, v.Address)
				assert.Equal(t, tt.wantResp[k].Count, v.Count)
			}
		})
	}
}

func TestIntegration_Event_GetCountByAddressAndEventName(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProveEventOpts)

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), dummyProposeEventOpts)

	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		address  string
		event    string
		wantResp int
		wantErr  error
	}{
		{
			"success",
			dummyProposeEventOpts.Address,
			dummyProposeEventOpts.Event,
			1,
			nil,
		},
		{
			"none",
			"0xfake",
			dummyProposeEventOpts.Event,
			0,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.GetCountByAddressAndEventName(
				context.Background(),
				tt.address,
				tt.event,
			)
			spew.Dump(resp)
			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, tt.wantResp, resp)
		})
	}
}

func TestIntegration_Event_Delete(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	event, err := eventRepo.Save(context.Background(), dummyProveEventOpts)

	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		id      int
		wantErr error
	}{
		{
			"success",
			event.ID,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := eventRepo.Delete(
				context.Background(),
				tt.id,
			)
			assert.Equal(t, tt.wantErr, err)

			foundEvent, err := eventRepo.FindByEventTypeAndBlockID(
				context.Background(),
				event.Event,
				event.BlockID.Int64,
			)

			assert.Equal(t, nil, err)
			assert.Nil(t, foundEvent)
		})
	}
}

func TestIntegration_Event_FirstByAddressAndEvent(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	event, err := eventRepo.Save(context.Background(), dummyProveEventOpts)

	assert.Equal(t, nil, err)

	tests := []struct {
		name        string
		address     string
		event       string
		wantErr     error
		wantEventID int
	}{
		{
			"success",
			dummyProveEventOpts.Address,
			dummyProveEventOpts.Name,
			nil,
			event.ID,
		},
		{
			"notFound",
			dummyProveEventOpts.Address,
			"fakeEvent",
			nil,
			0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			found, err := eventRepo.FirstByAddressAndEventName(
				context.Background(),
				tt.address,
				tt.event,
			)
			assert.Equal(t, tt.wantErr, err)

			if tt.wantEventID != 0 {
				assert.Equal(t, tt.wantEventID, found.ID)
			}
		})
	}
}

func TestIntegration_Event_GetBlockProposedBy(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	blockID := int64(0)

	batchBlockId := int64(2)

	numBlocks := int64(2)
	// Save a single BlockProposed event
	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBlockProposed,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBlockProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	// Save a BatchProposed event where blocks [0, 1] belong to the batch
	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBatchProposed,
		Address:      "0x1234",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameBlockProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &batchBlockId,
		TransactedAt: time.Now(),
		NumBlocks:    &numBlocks,
	})
	assert.Equal(t, nil, err)

	tests := []struct {
		name         string
		blockID      int64
		wantProposer string
		wantErr      error
	}{
		{
			"single block proposed event exists",
			0,
			"0x123",
			nil,
		},
		{
			"block is part of batch proposal",
			2,
			"0x1234",
			nil,
		},
		{
			"block does not exist",
			99, // No event with this block ID exists
			"",
			gorm.ErrRecordNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			event, err := eventRepo.GetBlockProposedBy(context.Background(), int(tt.blockID))

			assert.Equal(t, tt.wantErr, err)

			if tt.wantErr == nil {
				assert.NotNil(t, event)
				assert.Equal(t, tt.wantProposer, event.Address)
			} else {
				assert.Nil(t, event)
			}
		})
	}
}

func TestIntegration_Event_GetBlockProvenBy(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	blockID := int64(0)
	batchBlockID := int64(2)
	numBlocks := int64(2)
	batchID := int64(100)

	// Save a single TransitionProved event
	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameTransitionProved,
		Address:      "0x123",
		Data:         "{\"data\":\"something\"}",
		Event:        eventindexer.EventNameTransitionProved,
		ChainID:      big.NewInt(1),
		BlockID:      &blockID,
		TransactedAt: time.Now(),
	})
	assert.Equal(t, nil, err)

	// Save a BatchProposed event where blocks [0, 1] belong to the batch
	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBatchProposed,
		Address:      "0x1234",
		Data:         fmt.Sprintf("{\"batchID\": %d, \"num_blocks\": %d}", batchID, numBlocks),
		Event:        eventindexer.EventNameBatchProposed,
		ChainID:      big.NewInt(1),
		BlockID:      &batchBlockID,
		TransactedAt: time.Now(),
		NumBlocks:    &numBlocks,
		BatchID:      &batchID,
	})
	assert.Equal(t, nil, err)

	// Save a BatchesProven event for the batch
	_, err = eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameBatchesProven,
		Address:      "0x5678",
		Data:         fmt.Sprintf("{\"batchID\": %d}", batchID),
		Event:        eventindexer.EventNameBatchesProven,
		ChainID:      big.NewInt(1),
		TransactedAt: time.Now(),
		BatchID:      &batchID,
	})
	assert.Equal(t, nil, err)

	tests := []struct {
		name       string
		blockID    int64
		wantProver string
		wantErr    error
	}{
		{
			"single block proven event exists",
			0,
			"0x123",
			nil,
		},
		{
			"block is part of batch proof",
			1,
			"0x5678",
			nil,
		},
		{
			"block does not exist",
			99,
			"",
			gorm.ErrRecordNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			events, err := eventRepo.GetBlockProvenBy(context.Background(), int(tt.blockID))

			assert.Equal(t, tt.wantErr, err)

			if tt.wantErr == nil {
				assert.NotEmpty(t, events)
				assert.Equal(t, tt.wantProver, events[0].Address)
			} else {
				assert.Empty(t, events)
			}
		})
	}
}
