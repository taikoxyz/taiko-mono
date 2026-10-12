package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/mock"
)

func newTestServer() *Server {
	srv, err := NewServer(NewServerOpts{Echo: echo.New(), NFTBalanceRepo: mock.NewNFTBalanceRepository()})
	if err != nil {
		panic(err)
	}

	return srv
}

func TestNewServer(t *testing.T) {
	_, err := NewServer(NewServerOpts{Echo: echo.New()})
	require.Equal(t, eventindexer.ErrNoNFTBalanceRepository, err)
	_, err = NewServer(NewServerOpts{NFTBalanceRepo: mock.NewNFTBalanceRepository()})
	require.Equal(t, ErrNoHTTPFramework, err)
}

func TestProbes(t *testing.T) {
	srv := newTestServer()

	for _, path := range []string{"/", "/healthz"} {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusOK, rec.Code)
		require.Empty(t, rec.Body.String())
	}

	require.NoError(t, srv.Shutdown(context.Background()))
}

func TestNFTCORSAndRequestID(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/nftsByAddress?address=0x123&chainID=167000", nil)
	req.Header.Set(echo.HeaderOrigin, "https://bridge.taiko.xyz")

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	require.Equal(t, http.StatusOK, rec.Code)
	require.Equal(t, "*", rec.Header().Get(echo.HeaderAccessControlAllowOrigin))
	require.NotEmpty(t, rec.Header().Get(echo.HeaderXRequestID))
}
