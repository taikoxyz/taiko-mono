package http

import (
	"context"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func Test_GetEventsByAddress(t *testing.T) {
	srv := newTestServer("")

	_, err := srv.eventRepo.Save(context.Background(), relayer.SaveEventOpts{
		Name:        "name",
		Data:        `{"Owner": "0x0000000000000000000000000000000000000123"}`,
		ChainID:     big.NewInt(167001),
		DestChainID: big.NewInt(167002),
		Status:      relayer.EventStatusNew,
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name                  string
		address               string
		chainID               string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"successEmptyList",
			"0x456",
			"167001",
			http.StatusOK,
			[]string{`\[\]`},
		},
		{
			"success",
			"0x0000000000000000000000000000000000000123",
			"167001",
			http.StatusOK,
			[]string{`[{"id":780800018316137516,"name":"name",
			"data":{"Owner":"0x0000000000000000000000000000000000000123"},"status":0,"chainID":167001}]`},
		},
		{
			"successNoChainID",
			"0x0000000000000000000000000000000000000123",
			"",
			http.StatusOK,
			[]string{`[{"id":780800018316137516,"name":"name",
			"data":{"Owner":"0x0000000000000000000000000000000000000123"},"status":0,"chainID":167001}]`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/events?address=%v&chainID=%v",
					tt.address,
					tt.chainID),

				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
