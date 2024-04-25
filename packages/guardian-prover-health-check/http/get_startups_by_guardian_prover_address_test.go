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

func Test_GetStartupsByGuardianProverID(t *testing.T) {
	srv := newTestServer("")

	err := srv.startupRepo.Save(guardianproverhealthcheck.SaveStartupOpts{
		GuardianProverID:      1,
		GuardianProverAddress: "0x123",
		Revision:              "asdf",
		GuardianVersion:       "v1.0.0",
		L1NodeVersion:         "v1.0.0",
		L2NodeVersion:         "v1.0.0",
	})

	assert.Nil(t, err)

	assert.Equal(t, nil, err)

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
			[]string{`{"items":\[{"guardianProverID":1,"guardianProverAddress":"0x123","l1NodeVersion":"v1.0.0","l2NodeVersion":"v1.0.0","revision":"asdf","guardianVersion":"v1.0.0","createdAt":"0001-01-01T00:00:00Z"}\],"page":0,"size":0,"max_page":0,"total_pages":0,"total":0,"last":false,"first":false,"visible":0}`},
		},
		{
			"successDoesntExist",
			"9839483294",
			http.StatusOK,
			[]string{``},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/startups/%v", tt.id),
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
