package http

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
)

func Test_GetStats(t *testing.T) {
	srv := newTestServer("")

	tests := []struct {
		name                  string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"success",
			http.StatusOK,
			// nolint: lll
			[]string{``},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				"/stats",
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
