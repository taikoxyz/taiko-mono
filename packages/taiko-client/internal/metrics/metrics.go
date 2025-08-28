package metrics

import (
	"context"

	p2pNodeMetrics "github.com/ethereum-optimism/optimism/op-node/metrics"
	opMetrics "github.com/ethereum-optimism/optimism/op-service/metrics"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/log"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// An extended set of histogram buckers to have more granularity in the [0.5,
// 2.5] range.
var HistogramBuckets = []float64{.005, .01, .025, .05, .1, .25, .5, .75, 1, 1.25, 1.5, 1.75, 2, 2.5, 5, 10}

// Metrics
var (
	registry = opMetrics.NewRegistry()
	factory  = opMetrics.With(registry)

	// Driver
	DriverL1HeadHeightGauge                = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l1Head_height"})
	DriverL2HeadHeightGauge                = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Head_height"})
	DriverL2PreconfHeadHeightGauge         = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_preconf_l2Head_height"})
	DriverL1CurrentHeightGauge             = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l1Current_height"})
	DriverL2HeadIDGauge                    = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Head_id"})
	DriverL2VerifiedHeightGauge            = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_l2Verified_id"})
	DriverHighestPreconfUnsafePayloadGauge = factory.NewGauge(prometheus.GaugeOpts{Name: "driver_highest_unsafe_payload"})
	DriverReorgsByProposalCounter          = factory.NewCounter(prometheus.CounterOpts{Name: "driver_reorgs_by_proposal"})
	DriverPreconfEnvelopeCounter           = factory.NewCounter(prometheus.CounterOpts{Name: "driver_p2p_envelope"})
	DriverLastSeenBlockInProposalGauge     = factory.NewGauge(prometheus.GaugeOpts{
		Name: "driver_last_seen_block_in_proposal",
	})
	DriverL2PreconfBlocksFromRPCGauge = factory.NewGauge(prometheus.GaugeOpts{
		Name: "driver_preconf_blocks_from_rpc",
	})
	DriverPreconfInvalidEnvelopeCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_p2p_invalid_envelope",
	})
	DriverPreconfOutdatedEnvelopeCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_p2p_outdated_envelope",
	})
	DriverPreconfEnvelopeCachedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_p2p_envelope_cached",
	})
	DriverPreconfOnL2UnsafeRequestCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_on_l2_unsafe_request",
	})
	DriverPreconfOnL2UnsafeRequestDuration = factory.NewHistogram(prometheus.HistogramOpts{
		Name:    "driver_on_l2_unsafe_request_duration",
		Buckets: HistogramBuckets,
	})
	DriverPreconfOnL2UnsafeResponseCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_on_l2_unsafe_response",
	})
	DriverPreconfOnL2UnsafeResponseDuration = factory.NewHistogram(prometheus.HistogramOpts{
		Name:    "driver_on_l2_unsafe_response_duration",
		Buckets: HistogramBuckets,
	})
	DriverPreconfOnUnsafeL2PayloadDuration = factory.NewHistogram(prometheus.HistogramOpts{
		Name:    "driver_on_unsafe_l2_payload_duration",
		Buckets: HistogramBuckets,
	})
	DriverPreconfOnEndOfSequencingRequestCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_on_end_of_sequencing_request",
	})
	DriverPreconfOnEndOfSequencingRequestDuration = factory.NewHistogram(prometheus.HistogramOpts{
		Name:    "driver_on_end_of_sequencing_request_duration",
		Buckets: HistogramBuckets,
	})
	DriverImportedPreconBlocksFromCacheCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "driver_imported_preconf_blocks_from_cache",
	})
	DriverPreconfBuildPreconfBlockDuration = factory.NewHistogram(prometheus.HistogramOpts{
		Name:    "driver_preconf_build_preconf_block_duration",
		Buckets: HistogramBuckets,
	})

	// Proposer
	ProposerProposeEpochCounter    = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_epoch"})
	ProposerProposedTxListsCounter = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_proposed_txLists"})
	ProposerProposedTxsCounter     = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_proposed_txs"})
	ProposerPoolContentFetchTime   = factory.NewGauge(prometheus.GaugeOpts{Name: "proposer_pool_content_fetch_time"})
	ProposerEstimatedCostCalldata  = factory.NewGauge(prometheus.GaugeOpts{Name: "proposer_estimated_cost_calldata"})
	ProposerEstimatedCostBlob      = factory.NewGauge(prometheus.GaugeOpts{Name: "proposer_estimated_cost_blob"})
	ProposerProposeByCalldata      = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_propose_by_calldata"})
	ProposerProposeByBlob          = factory.NewCounter(prometheus.CounterOpts{Name: "proposer_propose_by_blob"})
	ProposerCostEstimationError    = factory.NewGauge(prometheus.GaugeOpts{Name: "proposer_cost_estimation_error"})

	// Prover
	ProverLatestVerifiedIDGauge      = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_latestVerified_id"})
	ProverLatestProvenBlockIDGauge   = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_latestProven_id"})
	ProverQueuedProofCounter         = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_queued"})
	ProverReceivedProofCounter       = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_received"})
	ProverSentProofCounter           = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_all_sent"})
	ProverProofsAssigned             = factory.NewCounter(prometheus.CounterOpts{Name: "prover_proof_assigned"})
	ProverReceivedProposedBlockGauge = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_proposed_received"})
	ProverReceivedProvenBlockGauge   = factory.NewGauge(prometheus.GaugeOpts{Name: "prover_proven_received"})
	ProverSubmissionAcceptedCounter  = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_accepted",
	})
	ProverSubmissionErrorCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_error",
	})
	ProverAggregationSubmissionErrorCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_aggregation_submission_error",
	})
	ProverSGXAggregationGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sgx_aggregation_generation_time",
	})
	ProverSGXAggregationGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_aggregation_generation_time_sum",
	})
	ProverSgxProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_generated",
	})
	ProverSgxProofGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sgx_generation_time",
	})
	ProverSgxProofGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_generation_time_sum",
	})
	ProverSgxProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_aggregation_generated",
	})
	ProverSgxGethAggregationGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sgx_geth_aggregation_generation_time",
	})
	ProverSgxGethAggregationGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_geth_aggregation_generation_time_sum",
	})
	ProverSgxGethProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_geth_generated",
	})
	ProverSgxGethProofGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sgx_geth_generation_time",
	})
	ProverSgxGethProofGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_geth_generation_time_sum",
	})
	ProverSgxGethProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sgx_geth_aggregation_generated",
	})
	ProverR0AggregationGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_r0_aggregation_generation_time",
	})
	ProverR0AggregationGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_aggregation_generation_time_sum",
	})
	ProverR0ProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_generated",
	})
	ProverR0ProofGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_r0_generation_time",
	})
	ProverR0ProofGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_generation_time_sum",
	})
	ProverR0ProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_r0_aggregation_generated",
	})
	ProverSP1AggregationGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sp1_aggregation_generation_time",
	})
	ProverSP1AggregationGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_aggregation_generation_time_sum",
	})
	ProverSp1ProofGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_generated",
	})
	ProverSP1ProofGenerationTime = factory.NewGauge(prometheus.GaugeOpts{
		Name: "prover_proof_sp1_generation_time",
	})
	ProverSP1ProofGenerationTimeSum = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_generation_time_sum",
	})
	ProverSp1ProofAggregationGeneratedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_sp1_aggregation_generated",
	})
	ProverSubmissionRevertedCounter = factory.NewCounter(prometheus.CounterOpts{
		Name: "prover_proof_submission_reverted",
	})

	// TxManager
	TxMgrMetrics   = txmgrMetrics.MakeTxMetrics("client", factory)
	P2PNodeMetrics = p2pNodeMetrics.NewMetrics("client")
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

	rpc.BlockOnInterruptsContext(ctx)

	return nil
}
