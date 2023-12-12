package http

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/labstack/echo/v4"
)

func Test_PostSignedBlock(t *testing.T) {
	srv := newTestServer("")

	tests := []struct {
		name       string
		body       signedBlock
		wantStatus int
	}{
		{
			"signatureNotRecoverableToGuardianProverAddress",
			signedBlock{
				BlockID:   1,
				BlockHash: "0x123",
				Signature: "0x123",
			},
			http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.POST,
				"/signedBlock",
				tt.body,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, []string{})
		})
	}
}
