package metrics

import (
	"context"

	opMetrics "github.com/ethereum-optimism/optimism/op-service/metrics"
	"github.com/ethereum-optimism/optimism/op-service/opio"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/log"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

// Metrics
var (
	registry = opMetrics.NewRegistry()
	factory  = opMetrics.With(registry)

	// Driver
	DriverL1HeadHeightGauge     = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l1Head_height"})
	DriverL2HeadHeightGauge     = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Head_height"})
	DriverL1CurrentHeightGauge  = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l1Current_height"})
	DriverL2HeadIDGauge         = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Head_id"})
	DriverL2VerifiedHeightGauge = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Verified_id"})

	// Proposer
	ProposerProposeEpochCounter    = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_epoch"})
	ProposerProposedTxListsCounter = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_proposed_txLists"})
	ProposerProposedTxsCounter     = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_proposed_txs"})

	// Prover
	ProverLatestVerifiedIDGauge      = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_latestVerified_id"})
	ProverLatestProvenBlockIDGauge   = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_latestProven_id"})
	ProverQueuedProofCounter         = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_queued"})
	ProverReceivedProofCounter       = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_received"})
	ProverSentProofCounter           = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_sent"})
	ProverProofsAssigned             = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_assigned"})
	ProverReceivedProposedBlockGauge = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_proposed_received"})
	ProverReceivedProvenBlockGauge   = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_proven_received"})
	ProverProvenByGuardianGauge      = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_proven_by_guardian"})
	ProverSubmissionAcceptedCounter  = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_accepted",
	})
	ProverSubmissionErrorCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_error",
	})
	ProverAggregationSubmissionErrorCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_aggregation_submission_error",
	})
	ProverSgxProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_generated",
	})
	ProverSgxProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_aggregation_generated",
	})
	ProverR0ProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_generated",
	})
	ProverR0ProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_aggregation_generated",
	})
	ProverSp1ProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_generated",
	})
	ProverSp1ProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_aggregation_generated",
	})
	ProverSubmissionRevertedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_reverted",
	})

	// TxManager
	TxMgrMetrics = txmgrMetrics.MakeTxMetrics("client", factory)
)

// Serve starts the metrics server on the given address, will be closed when the given
// context is cancelled.
func Serve(ctx context.Context, c *cli.Context) error {
	if !c.Bool(flags.MetricsEnabled.Name) {
		return nil
	}

	log.Info(
		"Starting metrics server",
		"host", c.String(flags.MetricsAddr.Name),
		"port", c.Int(flags.MetricsPort.Name),
	)

	server, err := opMetrics.StartServer(
		registry,
		c.String(flags.MetricsAddr.Name),
		c.Int(flags.MetricsPort.Name),
	)
	if err != nil {
		return err
	}

	defer func() {
		if err := server.Stop(ctx); err != nil {
			log.Error("Failed to close metrics server", "error", err)
		}
	}()

	opio.BlockOnInterruptsContext(ctx)

	return nil
}
