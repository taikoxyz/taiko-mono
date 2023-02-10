package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

var (
	relayerAddr = common.HexToAddress("0x71C7656EC7ab88b098defB751B7401B5f6d8976F")
)

func Test_canProcessMessage(t *testing.T) {
	tests := []struct {
		name           string
		eventStatus    relayer.EventStatus
		messageOwner   common.Address
		relayerAddress common.Address
		want           bool
	}{
		{
			"canProcess, eventStatusNew",
			relayer.EventStatusNew,
			relayerAddr,
			relayerAddr,
			true,
		},
		{
			"cantProcess, eventStatusDone",
			relayer.EventStatusDone,
			relayerAddr,
			relayerAddr,
			false,
		},
		{
			"cantProcess, eventStatusRetriable",
			relayer.EventStatusRetriable,
			relayerAddr,
			relayerAddr,
			false,
		},
		{
			"cantProcess, eventStatusNewOnlyOwner and relayer is not owner",
			relayer.EventStatusNewOnlyOwner,
			common.HexToAddress("0x"),
			relayerAddr,
			false,
		},
		{
			"canProcess, eventStatusOnlyOwner and relayer address is owner",
			relayer.EventStatusNewOnlyOwner,
			relayerAddr,
			relayerAddr,
			true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			canProcess := canProcessMessage(
				context.Background(),
				tt.eventStatus,
				tt.messageOwner,
				tt.relayerAddress,
			)

			assert.Equal(t, tt.want, canProcess)
		})
	}
}

func Test_eventStatusFromMsgHash(t *testing.T) {
	tests := []struct {
		name       string
		ctx        context.Context
		gasLimit   *big.Int
		signal     [32]byte
		wantErr    error
		wantStatus relayer.EventStatus
	}{
		{
			"eventStatusDone",
			context.Background(),
			nil,
			[32]byte{},
			nil,
			relayer.EventStatusDone,
		},
		{
			"eventStatusNewOnlyOwner, 0GasLimit",
			context.Background(),
			common.Big0,
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
		{
			"eventStatusNewOnlyOwner, nilGasLimit",
			context.Background(),
			nil,
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
		{
			"eventStatusNewOnlyOwner, non0GasLimit",
			context.Background(),
			big.NewInt(100),
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNew,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService()

			status, err := svc.eventStatusFromMsgHash(tt.ctx, tt.gasLimit, tt.signal)
			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
			}

			assert.Equal(t, tt.wantStatus, status)
		})
	}
}

func Test_eventTypeAmountAndCanonicalTokenFromEvent(t *testing.T) {
	tests := []struct {
		name               string
		event              *bridge.BridgeMessageSent
		wantEventType      relayer.EventType
		wantCanonicalToken relayer.CanonicalToken
		wantAmount         *big.Int
		wantError          error
	}{
		{
			"receiveERC20",
			&bridge.BridgeMessageSent{
				Message: bridge.IBridgeMessage{
					// nolint lll
					Data: common.Hex2Bytes("0c6fab8200000000000000000000000000000000000000000000000000000000000000800000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d9910000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d99100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000007a68000000000000000000000000e4337137828c93d0046212ebda8a82a24356b67b000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000004544553540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095465737445524332300000000000000000000000000000000000000000000000"),
				},
			},
			relayer.EventTypeSendERC20,
			relayer.CanonicalToken{
				ChainId:  big.NewInt(31336),
				Addr:     common.HexToAddress("0xe4337137828c93D0046212ebDa8a82a24356b67B"),
				Decimals: uint8(18),
				Symbol:   "TEST",
				Name:     "TestERC20",
			},
			big.NewInt(1),
			nil,
		},
		{
			"nilData",
			&bridge.BridgeMessageSent{
				Message: bridge.IBridgeMessage{
					// nolint lll
					DepositValue: big.NewInt(1),
					Data:         common.Hex2Bytes("00"),
				},
			},
			relayer.EventTypeSendETH,
			relayer.CanonicalToken{},
			big.NewInt(1),
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			eventType, canonicalToken, amount, err := eventTypeAmountAndCanonicalTokenFromEvent(tt.event)
			assert.Equal(t, tt.wantEventType, eventType)
			assert.Equal(t, tt.wantCanonicalToken, canonicalToken)
			assert.Equal(t, tt.wantAmount, amount)
			assert.Equal(t, tt.wantError, err)
		})
	}
}
