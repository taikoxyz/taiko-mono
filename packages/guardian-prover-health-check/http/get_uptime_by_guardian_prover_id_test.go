package http

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
)

func Test_GetUptimeByGuardianProverID(t *testing.T) {
	srv := newTestServer("")

	tests := []struct {
		name                  string
		id                    string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"success",
			"9839483294",
			http.StatusOK,
			[]string{`{"uptime":25.5,"numHealthChecksLast24Hours":10}`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/uptime/%v", tt.id),
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
