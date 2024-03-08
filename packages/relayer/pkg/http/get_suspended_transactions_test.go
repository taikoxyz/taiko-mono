package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func Test_GetSuspendedTransactions(t *testing.T) {
	srv := newTestServer("")

	_, err := srv.suspendedTxRepo.Save(context.Background(), relayer.SuspendTransactionOpts{
		MessageID:    1,
		MessageOwner: "0x1234",
		SrcChainID:   1,
		DestChainID:  2,
		MsgHash:      "0x456",
		Suspended:    true,
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name                  string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"success",
			http.StatusOK,
			// nolint: lll
			[]string{`{"items":\[{"id":1,"messageID":1,"srcChainID":1,"destChainID":2,"suspended":true,"msgHash":"0x456","messageOwner":"0x1234"}\],"page":0,"size":0,"max_page":0,"total_pages":0,"total":0,"last":false,"first":false,"visible":0}`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				"/suspendedTransactions",
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
