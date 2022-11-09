package repo

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"gopkg.in/go-playground/assert.v1"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

func Test_NewEventRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      *gorm.DB
		wantErr error
	}{
		{
			"success",
			&gorm.DB{},
			nil,
		},
		{
			"noDb",
			nil,
			relayer.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewEventRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Event_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)
	defer close()
	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    relayer.SaveEventOpts
		wantErr error
	}{
		{
			"success",
			relayer.SaveEventOpts{
				Name:    "test",
				ChainID: big.NewInt(1),
				Data:    "{\"data\":\"something\"}",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err = eventRepo.Save(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Event_UpdateStatus(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)
	defer close()
	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		id      int
		status  relayer.EventStatus
		wantErr bool
	}{
		{
			"success",
			1,
			relayer.EventStatusDone,
			false,
		},
		{
			"errNotFound",
			123,
			relayer.EventStatusDone,
			true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.name == "success" {
				eventRepo.Save(
					relayer.SaveEventOpts{
						Name:    "test",
						ChainID: big.NewInt(1),
						Data:    "{\"data\":\"something\"}",
					},
				)
			}
			err := eventRepo.UpdateStatus(tt.id, tt.status)
			assert.Equal(t, tt.wantErr, err != nil)
		})
	}
}

func TestIntegration_Event_FindAllByAddress(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)
	defer close()
	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)
	addr := common.HexToAddress("0x71C7656EC7ab88b098defB751B7401B5f6d8976F")

	_, err = eventRepo.Save(relayer.SaveEventOpts{
		Name:    "name",
		Data:    fmt.Sprintf(`{"Owner":"%s"}`, addr.Hex()),
		ChainID: big.NewInt(1),
		Status:  relayer.EventStatusDone,
	})
	assert.Equal(t, nil, err)
	tests := []struct {
		name     string
		chainID  *big.Int
		address  common.Address
		wantResp []*relayer.Event
		wantErr  error
	}{
		{
			"success",
			big.NewInt(1),
			addr,
			[]*relayer.Event{
				{
					ID:      1,
					Name:    "name",
					Data:    datatypes.JSON([]byte(fmt.Sprintf(`{"Owner": "%s"}`, addr.Hex()))),
					ChainID: 1,
					Status:  relayer.EventStatusDone,
				},
			},
			nil,
		},
		{
			"noneByChainID",
			big.NewInt(2),
			addr,
			[]*relayer.Event{},
			nil,
		},
		{
			"noneByAddr",
			big.NewInt(1),
			common.HexToAddress("0x165CD37b4C644C2921454429E7F9358d18A45e14"),
			[]*relayer.Event{},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.FindAllByAddress(tt.chainID, tt.address)
			assert.Equal(t, tt.wantResp, resp)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
