package metrics

import (
	"context"
	"fmt"
	"log/slog"
	"strconv"

	echoprom "github.com/labstack/echo-contrib/prometheus"
	"github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/urfave/cli/v2"
)

var nftIndexerLagBlocks = promauto.NewGaugeVec(prometheus.GaugeOpts{
	Name: "eventindexer_nft_indexer_lag_blocks",
	Help: "Observed RPC head minus the last completed NFT indexing position in blocks.",
}, []string{"chain_id"})

// SetNFTIndexerLag records lag against the last successfully completed position.
func SetNFTIndexerLag(chainID, head, completed uint64) {
	var lag uint64
	if head > completed {
		lag = head - completed
	}

	nftIndexerLagBlocks.WithLabelValues(strconv.FormatUint(chainID, 10)).Set(float64(lag))
}

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
			log.Error("Failed to close metrics server", "error", err)
		}
	}()

	slog.Info("Starting metrics server", "port", c.Uint64(flags.MetricsHTTPPort.Name))

	return e, func() error { return e.Start(fmt.Sprintf(":%v", c.Uint64(flags.MetricsHTTPPort.Name))) }
}
