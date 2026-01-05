package relayer

import (
	"testing"

	"gopkg.in/go-playground/assert.v1"
)

func Test_EventStatus_String(t *testing.T) {
	tests := []struct {
		name        string
		eventStatus EventStatus
		want        string
	}{
		{
			"new",
			EventStatusNew,
			"new",
		},
		{
			"retriable",
			EventStatusRetriable,
			"retriable",
		},
		{
			"failed",
			EventStatusFailed,
			"failed",
		},
		{
			"done",
			EventStatusDone,
			"done",
		},
		{
			"recalled",
			EventStatusRecalled,
			"recalled",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, tt.eventStatus.String())
		})
	}
}

func Test_EventType_String(t *testing.T) {
	tests := []struct {
		name      string
		eventType EventType
		want      string
	}{
		{
			"sendETH",
			EventTypeSendETH,
			"sendETH",
		},
		{
			"sendERC20",
			EventTypeSendERC20,
			"sendERC20",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, tt.eventType.String())
		})
	}
}
