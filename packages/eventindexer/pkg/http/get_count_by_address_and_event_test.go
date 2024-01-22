package http

import (
	"context"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func Test_GetCountByAddressAndEvent(t *testing.T) {
	srv := newTestServer("")

	_, err := srv.eventRepo.Save(context.Background(), eventindexer.SaveEventOpts{
		Name:         "name",
		Data:         `{"Owner": "0x0000000000000000000000000000000000000123"}`,
		ChainID:      big.NewInt(167001),
		Address:      "0x123",
		Event:        eventindexer.EventNameBlockProposed,
		TransactedAt: time.Now(),
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name                  string
		address               string
		event                 string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"successZeroCount",
			"0xhasntProposedAnything",
			eventindexer.EventNameBlockProposed,
			http.StatusOK,
			[]string{`{"count":0`},
		},
		{
			"success",
			"0x123",
			eventindexer.EventNameBlockProposed,
			http.StatusOK,
			[]string{`{"count":1`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/eventByAddress?address=%v&event=%v", tt.address, tt.event),
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
