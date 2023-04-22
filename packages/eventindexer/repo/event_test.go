package repo

import (
	"context"
	"math/big"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gotest.tools/assert"
)

var (
	dummyProveEventOpts = eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockProven,
		Address: "0x123",
		Data:    "{\"data\":\"something\"}",
		Event:   eventindexer.EventNameBlockProven,
		ChainID: big.NewInt(1),
	}
	dummyProposeEventOpts = eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockProposed,
		Address: "0x123",
		Data:    "{\"data\":\"something\"}",
		Event:   eventindexer.EventNameBlockProposed,
		ChainID: big.NewInt(1),
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
				Name:    "test",
				ChainID: big.NewInt(1),
				Data:    "{\"data\":\"something\"}",
				Event:   eventindexer.EventNameBlockProposed,
				Address: "0x123",
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
					Count:   1,
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
					Count:   1,
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
