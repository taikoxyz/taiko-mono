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

func Test_GetMostRecentSignedBlockByGuardianProverID(t *testing.T) {
	srv := newTestServer("")

	for i := 0; i < 10; i++ {
		err := srv.signedBlockRepo.Save(guardianproverhealthcheck.SaveSignedBlockOpts{
			GuardianProverID: 1,
			RecoveredAddress: "0x123",
			BlockID:          uint64(i),
			BlockHash:        "0x123",
			Signature:        "0x123",
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
			[]string{`{"guardianProverID":1,"blockID":9,"blockHash":"0x123","signature":"0x123","recoveredAddress":"0x123","createdAt":"0001-01-01T00:00:00Z"}`},
		},
		{
			"success",
			"9839483294",
			http.StatusInternalServerError,
			[]string{``},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/signedBlock/%v", tt.id),
				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}
