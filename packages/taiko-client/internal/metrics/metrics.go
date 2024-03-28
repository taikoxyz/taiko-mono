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
	// Driver
	DriverL1HeadHeightGauge     = metrics.NewRegisteredGauge("driver/l1Head/height", nil)
	DriverL2HeadHeightGauge     = metrics.NewRegisteredGauge("driver/l2Head/height", nil)
	DriverL1CurrentHeightGauge  = metrics.NewRegisteredGauge("driver/l1Current/height", nil)
	DriverL2HeadIDGauge         = metrics.NewRegisteredGauge("driver/l2Head/id", nil)
	DriverL2VerifiedHeightGauge = metrics.NewRegisteredGauge("driver/l2Verified/id", nil)

	// Proposer
	ProposerProposeEpochCounter    = metrics.NewRegisteredCounter("proposer/epoch", nil)
	ProposerProposedTxListsCounter = metrics.NewRegisteredCounter("proposer/proposed/txLists", nil)
	ProposerProposedTxsCounter     = metrics.NewRegisteredCounter("proposer/proposed/txs", nil)

	// Prover
	ProverLatestVerifiedIDGauge      = metrics.NewRegisteredGauge("prover/latestVerified/id", nil)
	ProverLatestProvenBlockIDGauge   = metrics.NewRegisteredGauge("prover/latestProven/id", nil)
	ProverQueuedProofCounter         = metrics.NewRegisteredCounter("prover/proof/all/queued", nil)
	ProverReceivedProofCounter       = metrics.NewRegisteredCounter("prover/proof/all/received", nil)
	ProverSentProofCounter           = metrics.NewRegisteredCounter("prover/proof/all/sent", nil)
	ProverProofsAssigned             = metrics.NewRegisteredCounter("prover/proof/assigned", nil)
	ProverReceivedProposedBlockGauge = metrics.NewRegisteredGauge("prover/proposed/received", nil)
	ProverReceivedProvenBlockGauge   = metrics.NewRegisteredGauge("prover/proven/received", nil)
	ProverSubmissionAcceptedCounter  = metrics.NewRegisteredCounter("prover/proof/submission/accepted", nil)
	ProverSubmissionErrorCounter     = metrics.NewRegisteredCounter("prover/proof/submission/error", nil)
	ProverSgxProofGeneratedCounter   = metrics.NewRegisteredCounter("prover/proof/sgx/generated", nil)
	ProverPseProofGeneratedCounter   = metrics.NewRegisteredCounter("prover/proof/pse/generated", nil)

	// Transaction sender
	TxSenderSentCounter                = metrics.NewRegisteredCounter("sender/sent/txs", nil)
	TxSenderConfirmedSuccessfulCounter = metrics.NewRegisteredCounter("sender/confirmed/successful/txs", nil)
	TxSenderConfirmedFailedCounter     = metrics.NewRegisteredCounter("sender/confirmed/failed/txs", nil)
	TxSenderUnconfirmedCounter         = metrics.NewRegisteredCounter("sender/unconfirmed/txs", nil)
	TxSenderGasPriceGauge              = metrics.NewRegisteredGauge("sender/gasPrice", nil)
	TxSenderBlobGasPriceGauge          = metrics.NewRegisteredGauge("sender/blob/gasPrice", nil)
	TxSenderTxIncludedTimeGauge        = metrics.NewRegisteredGauge("sender/tx/includedTime", nil)
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
