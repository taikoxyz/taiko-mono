package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func Test_GetStats(t *testing.T) {
	srv := newTestServer("")

	var proofTime uint64 = 5

	var proofReward uint64 = 7

	_, err := srv.statRepo.Save(context.Background(), eventindexer.SaveStatOpts{
		ProofTime:   &proofTime,
		ProofReward: &proofReward,
	})

	assert.Equal(t, nil, err)

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
			[]string{`{"id":1,"averageProofTime":5,"averageProofReward":7,"numProofs":1,"numVerifiedBlocks":1}`},
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
