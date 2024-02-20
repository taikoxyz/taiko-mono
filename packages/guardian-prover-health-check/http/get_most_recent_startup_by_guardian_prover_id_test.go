package http

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

func Test_GetMostRecentStartupByGuardianProverID(t *testing.T) {
	srv := newTestServer("")

	for i := 0; i < 5; i++ {
		err := srv.startupRepo.Save(guardianproverhealthcheck.SaveStartupOpts{
			GuardianProverID:      1,
			GuardianProverAddress: "0x123",
			Revision:              "asdf",
			GuardianVersion:       "v1.0.0",
			L1NodeVersion:         "v1.0.0",
			L2NodeVersion:         "v1.0.0",
		})

		assert.Nil(t, err)
	}

	tests := []struct {
		name                  string
		id                    string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"success",
			"1",
			http.StatusOK,
			// nolint: lll
			[]string{`{"guardianProverID":1,"guardianProverAddress":"0x123","l1NodeVersion":"v1.0.0","l2NodeVersion":"v1.0.0","revision":"asdf","guardianVersion":"v1.0.0","createdAt":"0001-01-01T00:00:00Z"}`},
		},
		{
			"doesntExist",
			"9839483294",
			http.StatusBadRequest,
			[]string{``},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/mostRecentStartup/%v", tt.id),
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
