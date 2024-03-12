package repo

import (
	"context"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"gopkg.in/go-playground/assert.v1"
	"gorm.io/datatypes"
)

var testMsgHash = "0x1"
var testSecondMsgHash = "0x2"
var testEventTypeSendETH = relayer.EventTypeSendETH
var testEventTypeSendERC20 = relayer.EventTypeSendERC20
var addr = common.HexToAddress("0x71C7656EC7ab88b098defB751B7401B5f6d8976F")

var testEvents = []relayer.Event{
	{
		ID:   1,
		Name: "name",
		// nolint lll
		Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
		ChainID:                1,
		DestChainID:            2,
		Status:                 relayer.EventStatusDone,
		EventType:              testEventTypeSendETH,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "ETH",
		CanonicalTokenName:     "Ethereum",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                testMsgHash,
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageSent,
		EmittedBlockID:         1,
	},
	{
		ID:   2,
		Name: "name",
		// nolint lll
		Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
		ChainID:                1,
		DestChainID:            2,
		Status:                 relayer.EventStatusDone,
		EventType:              testEventTypeSendERC20,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "FAKE",
		CanonicalTokenName:     "Fake Token",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                testMsgHash,
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageSent,
		EmittedBlockID:         1,
	},
	{
		ID:   3,
		Name: "name",
		// nolint lll
		Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
		ChainID:                1,
		DestChainID:            2,
		Status:                 relayer.EventStatusDone,
		EventType:              testEventTypeSendERC20,
		CanonicalTokenAddress:  "0x2",
		CanonicalTokenSymbol:   "FAKE",
		CanonicalTokenName:     "Fake Token",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                testSecondMsgHash,
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageStatusChanged,
		EmittedBlockID:         1,
	},
}

func Test_NewEventRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      DB
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
			ErrNoDB,
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
				DestChainID:            big.NewInt(2),
				Data:                   "{\"data\":\"something\"}",
				EventType:              relayer.EventType(relayer.EventTypeSendETH),
				CanonicalTokenAddress:  "0x1",
				CanonicalTokenSymbol:   "ETH",
				CanonicalTokenName:     "Ethereum",
				CanonicalTokenDecimals: 18,
				Amount:                 "1",
				MsgHash:                "0x1",
				MessageOwner:           "0x1",
				Event:                  relayer.EventNameMessageSent,
				EmittedBlockID:         1,
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
						DestChainID:            big.NewInt(2),
						Data:                   "{\"data\":\"something\"}",
						EventType:              relayer.EventTypeSendETH,
						CanonicalTokenAddress:  "0x1",
						CanonicalTokenSymbol:   "ETH",
						CanonicalTokenName:     "Ethereum",
						CanonicalTokenDecimals: 18,
						Amount:                 "1",
						MsgHash:                "0x1",
						MessageOwner:           "0x1",
						Event:                  relayer.EventNameMessageSent,
						EmittedBlockID:         1,
					},
				)
				assert.Equal(t, nil, err)
			}

			err := eventRepo.UpdateStatus(context.Background(), tt.id, tt.status)

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

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		DestChainID:            big.NewInt(2),
		Status:                 relayer.EventStatusDone,
		EventType:              relayer.EventTypeSendETH,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "ETH",
		CanonicalTokenName:     "Ethereum",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                "0x1",
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageSent,
		EmittedBlockID:         1,
	})

	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		DestChainID:            big.NewInt(2),
		Status:                 relayer.EventStatusDone,
		EventType:              relayer.EventTypeSendERC20,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "FAKE",
		CanonicalTokenName:     "Fake Token",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                "0x1",
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageSent,
		EmittedBlockID:         1,
	})
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		DestChainID:            big.NewInt(2),
		Status:                 relayer.EventStatusDone,
		EventType:              relayer.EventTypeSendERC20,
		CanonicalTokenAddress:  "0x2",
		CanonicalTokenSymbol:   "FAKE",
		CanonicalTokenName:     "Fake Token",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                "0x2",
		MessageOwner:           addr.Hex(),
		Event:                  relayer.EventNameMessageStatusChanged,
		EmittedBlockID:         1,
	})
	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		opts     relayer.FindAllByAddressOpts
		wantResp paginate.Page
		wantErr  error
	}{
		{
			"successJustAddress",
			relayer.FindAllByAddressOpts{
				Address: addr,
			},
			paginate.Page{
				Items:      testEvents,
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"successJustAddressAndEvent",
			relayer.FindAllByAddressOpts{
				Address: addr,
				Event:   &relayer.EventNameMessageSent,
			},
			paginate.Page{
				Items:      testEvents[:2],
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"successAddressAndMsgHash",
			relayer.FindAllByAddressOpts{
				Address: addr,
				MsgHash: &testMsgHash,
			},
			paginate.Page{
				Items:      testEvents[:2],
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"successAddressAndEventType",
			relayer.FindAllByAddressOpts{
				Address:   addr,
				EventType: &testEventTypeSendERC20,
			},
			paginate.Page{
				Items:      testEvents[1:3],
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"successAddressMsgHashAndEventType",
			relayer.FindAllByAddressOpts{
				Address:   addr,
				EventType: &testEventTypeSendERC20,
				MsgHash:   &testSecondMsgHash,
			},
			paginate.Page{
				Items:      testEvents[2:],
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"successAddressMsgHashAndEvent",
			relayer.FindAllByAddressOpts{
				Address: addr,
				MsgHash: &testSecondMsgHash,
				Event:   &relayer.EventNameMessageStatusChanged,
			},
			paginate.Page{
				Items:      testEvents[2:],
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
		{
			"noneByAddr",
			relayer.FindAllByAddressOpts{
				Address: common.HexToAddress("0x165CD37b4C644C2921454429E7F9358d18A45e14"),
			},
			paginate.Page{
				Items:      []relayer.Event{},
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       true,
				First:      true,
				Visible:    1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, err := http.NewRequest(http.MethodGet, "/events", nil)
			assert.Equal(t, nil, err)

			resp, err := eventRepo.FindAllByAddress(context.Background(), req, tt.opts)
			assert.Equal(t, tt.wantResp.Items, resp.Items)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Event_FirstByMsgHash(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	eventRepo, err := NewEventRepository(db)
	assert.Equal(t, nil, err)

	_, err = eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:                   "name",
		Data:                   fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())),
		ChainID:                big.NewInt(1),
		DestChainID:            big.NewInt(2),
		Status:                 relayer.EventStatusDone,
		EventType:              relayer.EventTypeSendETH,
		CanonicalTokenAddress:  "0x1",
		CanonicalTokenSymbol:   "ETH",
		CanonicalTokenName:     "Ethereum",
		CanonicalTokenDecimals: 18,
		Amount:                 "1",
		MsgHash:                "0x1",
		MessageOwner:           addr.Hex(),
		EmittedBlockID:         1,
	})
	assert.Equal(t, nil, err)
	tests := []struct {
		name     string
		msgHash  string
		wantResp *relayer.Event
		wantErr  error
	}{
		{
			"success",
			"0x1",
			&relayer.Event{
				ID:   1,
				Name: "name",
				// nolint lll
				Data:                   datatypes.JSON([]byte(fmt.Sprintf(`{"Message": {"Owner": "%s"}}`, strings.ToLower(addr.Hex())))),
				ChainID:                1,
				DestChainID:            2,
				Status:                 relayer.EventStatusDone,
				EventType:              relayer.EventTypeSendETH,
				CanonicalTokenAddress:  "0x1",
				CanonicalTokenSymbol:   "ETH",
				CanonicalTokenName:     "Ethereum",
				CanonicalTokenDecimals: 18,
				Amount:                 "1",
				MsgHash:                "0x1",
				MessageOwner:           addr.Hex(),
				EmittedBlockID:         1,
			},
			nil,
		},
		{
			"noneByMgHash",
			"0xfake",
			nil,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := eventRepo.FirstByMsgHash(context.Background(), tt.msgHash)
			assert.Equal(t, tt.wantResp, resp)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
