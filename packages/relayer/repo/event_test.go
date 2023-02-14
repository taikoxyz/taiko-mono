package repo

import (
	"context"
	"fmt"
	"math/big"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/db"
	"gopkg.in/go-playground/assert.v1"
	"gorm.io/datatypes"
)

func Test_NewEventRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      relayer.DB
		wantErr error
	}{
		{
			"success",
			&db.DB{},
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
				Name:                   "test",
				ChainID:                big.NewInt(1),
				Data:                   "{\"data\":\"something\"}",
				EventType:              relayer.EventType(relayer.EventTypeSendETH),
				CanonicalTokenAddress:  "0x1",
				CanonicalTokenSymbol:   "ETH",
				CanonicalTokenName:     "Ethereum",
				CanonicalTokenDecimals: 18,
				Amount:                 "1",
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
				_, err := eventRepo.Save(context.Background(),
					relayer.SaveEventOpts{
						Name:                   "test",
						ChainID:                big.NewInt(1),
						Data:                   "{\"data\":\"something\"}",
						EventType:              relayer.EventTypeSendETH,
						CanonicalTokenAddress:  "0x1",
						CanonicalTokenSymbol:   "ETH",
						CanonicalTokenName:     "Ethereum",
						CanonicalTokenDecimals: 18,
						Amount:                 "1",
					},
				)
				assert.Equal(t, nil, err)
			}
			err := eventRepo.UpdateStatus(context.Background(), tt.id, tt.status)
			assert.Equal(t, tt.wantErr, err != nil)
		})
	}
}

func TestIntegration_Event_FindAllByAddressAndChainID(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	addr := common.HexToAddress("0x71C7656EC7ab88b098defB751B7401B5f6d8976F")

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		Status:                 relayer.EventStatusDone,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "ETH",
		CanonicalTokenName:     "Ethereum",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
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
					ID:   1,
					Name: "name",
					// nolint lll
					Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
					ChainID:                1,
					Status:                 relayer.EventStatusDone,
					EventType:              relayer.EventTypeSendETH,
					CanonicalTokenAddress:  "0x1",
					CanonicalTokenSymbol:   "ETH",
					CanonicalTokenName:     "Ethereum",
					CanonicalTokenDecimals: 18,
					Amount:                 "1",
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
			resp, err := eventRepo.FindAllByAddressAndChainID(context.Background(), tt.chainID, tt.address)
			assert.Equal(t, tt.wantResp, resp)
			assert.Equal(t, tt.wantErr, err)
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

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		Status:                 relayer.EventStatusDone,
		EventType:              relayer.EventTypeSendETH,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "ETH",
		CanonicalTokenName:     "Ethereum",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
	})
	assert.Equal(t, nil, err)
	tests := []struct {
		name     string
		address  common.Address
		wantResp []*relayer.Event
		wantErr  error
	}{
		{
			"success",
			addr,
			[]*relayer.Event{
				{
					ID:   1,
					Name: "name",
					// nolint lll
					Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
					ChainID:                1,
					Status:                 relayer.EventStatusDone,
					EventType:              relayer.EventTypeSendETH,
					CanonicalTokenAddress:  "0x1",
					CanonicalTokenSymbol:   "ETH",
					CanonicalTokenName:     "Ethereum",
					CanonicalTokenDecimals: 18,
					Amount:                 "1",
				},
			},
			nil,
		},
		{
			"noneByAddr",
			common.HexToAddress("0x165CD37b4C644C2921454429E7F9358d18A45e14"),
			[]*relayer.Event{},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.FindAllByAddress(context.Background(), tt.address)
			assert.Equal(t, tt.wantResp, resp)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
