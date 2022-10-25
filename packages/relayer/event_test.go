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
			"done",
			EventStatusDone,
			"done",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, tt.eventStatus.String())
		})
	}
}
