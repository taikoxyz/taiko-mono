package http

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
)

func Test_GetPOSStats(t *testing.T) {
	srv := newTestServer("")

	srv.cache.Set(CacheKeyPOSStats, &posStatsResponse{
		TotalSlashedTokens:      "1",
		CurrentProtocolCapacity: "1",
	}, 10*time.Second)

	tests := []struct {
		name                  string
		address               string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"success",
			"0x123",
			http.StatusOK,
			[]string{`{"totalSlashedTokens":"1","currentProtocolCapacity":"1"}`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				"/posStats",
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
