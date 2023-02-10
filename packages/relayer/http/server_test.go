package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/joho/godotenv"
	echo "github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/repo"
)

func newTestServer(url string) *Server {
	_ = godotenv.Load("../.test.env")

	srv := &Server{
		echo:      echo.New(),
		eventRepo: mock.NewEventRepository(),
	}

	srv.configureMiddleware([]string{"*"})
	srv.configureRoutes()
	srv.configureAndStartPrometheus()

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
				L1EthClient: &mock.EthClient{},
				L2EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
			},
			nil,
		},
		{
			"noL1EthClient",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
				L2EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
			},
			relayer.ErrNoEthClient,
		},
		{
			"noL2EthClient",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
				L1EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
			},
			relayer.ErrNoEthClient,
		},
		{
			"noBlockRepo",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
				L1EthClient: &mock.EthClient{},
				L2EthClient: &mock.EthClient{},
			},
			relayer.ErrNoBlockRepository,
		},
		{
			"noEventRepo",
			NewServerOpts{
				Echo:        echo.New(),
				CorsOrigins: make([]string, 0),
				L1EthClient: &mock.EthClient{},
				L2EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
			},
			relayer.ErrNoEventRepository,
		},
		{
			"noCorsOrigins",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				L1EthClient: &mock.EthClient{},
				L2EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
			},
			relayer.ErrNoCORSOrigins,
		},
		{
			"noHttpFramework",
			NewServerOpts{
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
				L1EthClient: &mock.EthClient{},
				L2EthClient: &mock.EthClient{},
				BlockRepo:   &mock.BlockRepository{},
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

	req, _ := http.NewRequest(echo.GET, "/healthz", nil)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Test_Health expected code %v, got %v", http.StatusOK, rec.Code)
	}
}

func Test_Root(t *testing.T) {
	srv := newTestServer("")

	req, _ := http.NewRequest(echo.GET, "/", nil)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Test_Root expected code %v, got %v", http.StatusOK, rec.Code)
	}
}

func Test_Metrics(t *testing.T) {
	srv := newTestServer("")

	req, _ := http.NewRequest(echo.GET, "/metrics", nil)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Test_Metrics expected code %v, got %v", http.StatusOK, rec.Code)
	}
}

func Test_StartShutdown(t *testing.T) {
	srv := newTestServer("")

	go func() {
		_ = srv.Start(":3928")
	}()
	assert.Nil(t, srv.Shutdown(context.Background()))
}
