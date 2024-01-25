package metrics

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/flags"
	"github.com/urfave/cli/v2"
)

func Test_Metrics(t *testing.T) {
	app := cli.NewApp()
	app.Flags = []cli.Flag{
		flags.MetricsHTTPPort,
	}

	app.Action = func(c *cli.Context) error {
		ctx, cancel := context.WithCancel(context.Background())

		var e *echo.Echo

		var startFunc func() error

		var err error

		go func() {
			e, startFunc = Serve(ctx, c)

			err = startFunc()
		}()

		for e == nil && err == nil {
			time.Sleep(1 * time.Second)
		}

		assert.Nil(t, err)
		assert.NotNil(t, e)

		req, _ := http.NewRequest(echo.GET, "/metrics", nil)
		rec := httptest.NewRecorder()

		e.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("Test_Metrics expected code %v, got %v", http.StatusOK, rec.Code)
		}

		cancel()

		assert.Nil(t, err)

		return nil
	}

	assert.Nil(t, app.Run([]string{
		"TestMetrics",
		"-" + flags.MetricsHTTPPort.Name, "5019",
	}))
}
