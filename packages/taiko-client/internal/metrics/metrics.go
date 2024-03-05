package metrics

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/metrics"
	"github.com/ethereum/go-ethereum/metrics/prometheus"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-client/cmd/flags"
)

// Metrics
var (
	// taiko metrics registry.
	taikoMetrics = metrics.NewRegistry()

	// Driver
	DriverL1HeadHeightGauge     = metrics.NewRegisteredGauge("driver/l1Head/height", taikoMetrics)
	DriverL2HeadHeightGauge     = metrics.NewRegisteredGauge("driver/l2Head/height", taikoMetrics)
	DriverL1CurrentHeightGauge  = metrics.NewRegisteredGauge("driver/l1Current/height", taikoMetrics)
	DriverL2HeadIDGauge         = metrics.NewRegisteredGauge("driver/l2Head/id", taikoMetrics)
	DriverL2VerifiedHeightGauge = metrics.NewRegisteredGauge("driver/l2Verified/id", taikoMetrics)

	// Proposer
	ProposerProposeEpochCounter    = metrics.NewRegisteredCounter("proposer/epoch", taikoMetrics)
	ProposerProposedTxListsCounter = metrics.NewRegisteredCounter("proposer/proposed/txLists", taikoMetrics)
	ProposerProposedTxsCounter     = metrics.NewRegisteredCounter("proposer/proposed/txs", taikoMetrics)

	// Prover
	ProverLatestVerifiedIDGauge      = metrics.NewRegisteredGauge("prover/latestVerified/id", taikoMetrics)
	ProverLatestProvenBlockIDGauge   = metrics.NewRegisteredGauge("prover/latestProven/id", taikoMetrics)
	ProverQueuedProofCounter         = metrics.NewRegisteredCounter("prover/proof/all/queued", taikoMetrics)
	ProverReceivedProofCounter       = metrics.NewRegisteredCounter("prover/proof/all/received", taikoMetrics)
	ProverSentProofCounter           = metrics.NewRegisteredCounter("prover/proof/all/sent", taikoMetrics)
	ProverProofsAssigned             = metrics.NewRegisteredCounter("prover/proof/assigned", taikoMetrics)
	ProverReceivedProposedBlockGauge = metrics.NewRegisteredGauge("prover/proposed/received", taikoMetrics)
	ProverReceivedProvenBlockGauge   = metrics.NewRegisteredGauge("prover/proven/received", taikoMetrics)
	ProverSubmissionAcceptedCounter  = metrics.NewRegisteredCounter("prover/proof/submission/accepted", taikoMetrics)
	ProverSubmissionErrorCounter     = metrics.NewRegisteredCounter("prover/proof/submission/error", taikoMetrics)
	ProverSgxProofGeneratedCounter   = metrics.NewRegisteredCounter("prover/proof/sgx/generated", taikoMetrics)
	ProverPseProofGeneratedCounter   = metrics.NewRegisteredCounter("prover/proof/pse/generated", taikoMetrics)
)

// Serve starts the metrics server on the given address, will be closed when the given
// context is cancelled.
func Serve(ctx context.Context, c *cli.Context) error {
	if !c.Bool(flags.MetricsEnabled.Name) {
		return nil
	}

	address := net.JoinHostPort(
		c.String(flags.MetricsAddr.Name),
		strconv.Itoa(c.Int(flags.MetricsPort.Name)),
	)

	server := http.Server{
		ReadHeaderTimeout: time.Minute,
		Addr:              address,
		Handler:           prometheus.Handler(metrics.DefaultRegistry),
	}

	go func() {
		<-ctx.Done()
		if err := server.Close(); err != nil {
			log.Error("Failed to close metrics server", "error", err)
		}
	}()

	log.Info("Starting metrics server", "address", address)

	return server.ListenAndServe()
}
