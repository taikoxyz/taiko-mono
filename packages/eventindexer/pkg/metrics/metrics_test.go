package metrics

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/urfave/cli/v2"
)

func Test_Metrics(t *testing.T) {
	app := cli.NewApp()
	app.Flags = []cli.Flag{
		flags.MetricsHTTPPort,
	}

	app.Action = func(c *cli.Context) error {
		ctx, cancel := context.WithCancel(context.Background())

		defer cancel()

		e, _ := Serve(ctx, c)
		assert.NotNil(t, e)
		SetNFTIndexerLag(167, 100, 90)

		req, _ := http.NewRequest(echo.GET, "/metrics", nil)
		rec := httptest.NewRecorder()

		e.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("Test_Metrics expected code %v, got %v", http.StatusOK, rec.Code)
		}

		assert.Contains(t, rec.Body.String(), `eventindexer_nft_indexer_lag_blocks{chain_id="167"} 10`)
		SetNFTIndexerLag(167, 80, 90)

		rec = httptest.NewRecorder()
		e.ServeHTTP(rec, req)
		assert.Contains(t, rec.Body.String(), `eventindexer_nft_indexer_lag_blocks{chain_id="167"} 0`)
		cancel()

		return nil
	}

	assert.Nil(t, app.Run([]string{
		"TestMetrics",
		"-" + flags.MetricsHTTPPort.Name, "0",
	}))
}
