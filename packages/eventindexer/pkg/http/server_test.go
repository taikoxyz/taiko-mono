package http

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/joho/godotenv"
	echo "github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
)

func newTestServer(url string) *Server {
	_ = godotenv.Load("../.test.env")

	srv := &Server{
		cache:          cache.New(5*time.Second, 6*time.Second),
		echo:           echo.New(),
		eventRepo:      mock.NewEventRepository(),
		statRepo:       mock.NewStatRepository(),
		nftBalanceRepo: mock.NewNFTBalanceRepository(),
	}

	srv.configureMiddleware([]string{"*"})
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
				Echo:           echo.New(),
				EventRepo:      &repo.EventRepository{},
				CorsOrigins:    make([]string, 0),
				StatRepo:       &repo.StatRepository{},
				NFTBalanceRepo: &repo.NFTBalanceRepository{},
			},
			nil,
		},
		{
			"noNftBalanceRepo",
			NewServerOpts{
				Echo:        echo.New(),
				EventRepo:   &repo.EventRepository{},
				CorsOrigins: make([]string, 0),
				StatRepo:    &repo.StatRepository{},
			},
			eventindexer.ErrNoNFTBalanceRepository,
		},
		{
			"noStatRepo",
			NewServerOpts{
				Echo:           echo.New(),
				EventRepo:      &repo.EventRepository{},
				CorsOrigins:    make([]string, 0),
				NFTBalanceRepo: &repo.NFTBalanceRepository{},
			},
			eventindexer.ErrNoStatRepository,
		},
		{
			"noEventRepo",
			NewServerOpts{
				Echo:           echo.New(),
				CorsOrigins:    make([]string, 0),
				StatRepo:       &repo.StatRepository{},
				NFTBalanceRepo: &repo.NFTBalanceRepository{},
			},
			eventindexer.ErrNoEventRepository,
		},
		{
			"noCorsOrigins",
			NewServerOpts{
				Echo:           echo.New(),
				EventRepo:      &repo.EventRepository{},
				StatRepo:       &repo.StatRepository{},
				NFTBalanceRepo: &repo.NFTBalanceRepository{},
			},
			eventindexer.ErrNoCORSOrigins,
		},
		{
			"noHttpFramework",
			NewServerOpts{
				EventRepo:      &repo.EventRepository{},
				CorsOrigins:    make([]string, 0),
				StatRepo:       &repo.StatRepository{},
				NFTBalanceRepo: &repo.NFTBalanceRepository{},
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

func Test_StartShutdown(t *testing.T) {
	srv := newTestServer("")

	go func() {
		_ = srv.Start(":3928")
	}()
	assert.Nil(t, srv.Shutdown(context.Background()))
}
