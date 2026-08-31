package metrics

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
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

		// Serve only builds the server; the returned func is what binds the port. The
		// route can be exercised in process, so the test never has to listen for real
		// -- doing so would race e.Start against the ServeHTTP below.
		e, startFunc := Serve(ctx, c)

		assert.NotNil(t, e)
		assert.NotNil(t, startFunc)

		req, _ := http.NewRequest(echo.GET, "/metrics", nil)
		rec := httptest.NewRecorder()

		e.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("Test_Metrics expected code %v, got %v", http.StatusOK, rec.Code)
		}

		return nil
	}

	assert.Nil(t, app.Run([]string{
		"TestMetrics",
		"-" + flags.MetricsHTTPPort.Name, "5019",
	}))
}
