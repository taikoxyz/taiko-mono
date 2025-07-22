package balanceMonitor

import (
	"context"
	"fmt"

	echoprom "github.com/labstack/echo-contrib/prometheus"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/balance-monitor/cmd/flags"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

// Serve starts the metrics server on the given address, will be closed when the given
// context is cancelled.
func Serve(ctx context.Context, c *cli.Context) (*echo.Echo, func() error) {
	// Enable metrics middleware
	p := echoprom.NewPrometheus("echo", nil)
	e := echo.New()
	p.SetMetricsPath(e)

	go func() {
		<-ctx.Done()

		if err := e.Shutdown(ctx); err != nil {
			slog.Error("Failed to close metrics server", "error", err)
		}
	}()

	slog.Info("Starting metrics server", "port", c.Uint64(flags.MetricsHTTPPort.Name))

	return e, func() error { return e.Start(fmt.Sprintf(":%v", c.Uint64(flags.MetricsHTTPPort.Name))) }
}
