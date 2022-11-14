package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/joho/godotenv"
	echo "github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
)

var includeTokens = []string{"1INCH"}

func newTestServer(url string) *Server {
	_ = godotenv.Load("../.test.env")

	srv := &Server{
		echo:      echo.New(),
		eventRepo: mock.NewEventRepository(),
	}
	srv.configureRoutes()

	return srv
}

func Test_NewServer(t *testing.T) {
	tests := []struct {
		name    string
		opts    NewServerOpts
		wantErr error
	}{
		{
			"success",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
			},
			nil,
		},
		{
			"noEventRepo",
			NewServerOpts{
				Echo:        echo.New(),
				CorsOrigins: make([]string, 0),
			},
			relayer.ErrNoEventRepository,
		},
		{
			"noHttpFramework",
			NewServerOpts{
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
			},
			ErrNoHTTPFramework,
		},
	}

	for _, tt := range tests {
		_, err := NewServer(tt.opts)
		assert.Equal(t, tt.wantErr, err)
	}
}

func Test_Health(t *testing.T) {
	srv := newTestServer("")

	req, _ := http.NewRequest(echo.GET, "/health", nil)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Test_Health expected code %v, got %v", http.StatusOK, rec.Code)
	}
}

func Test_StartShutdown(t *testing.T) {
	srv := newTestServer("")

	go func() {
		_ = srv.Start(":3928")
	}()
	assert.Nil(t, srv.Shutdown(context.Background()))
}
