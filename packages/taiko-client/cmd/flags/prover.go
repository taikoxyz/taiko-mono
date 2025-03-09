package flags

import (
	"time"

	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Required flags used by prover.
var (
	L1ProverPrivKey = &cli.StringFlag{
		Name:     "l1.proverPrivKey",
		Usage:    "Private key of L1 prover, who will send TaikoL1.proveBlock transactions",
		Required: true,
		Category: proverCategory,
		EnvVars:  []string{"L1_PROVER_PRIV_KEY"},
	}
)

// Optional flags used by prover.
var (
	RaikoHostEndpoint = &cli.StringFlag{
		Name:     "raiko.host",
		Usage:    "RPC endpoint of a Raiko host service",
		Required: true,
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_HOST"},
	}
	RaikoZKVMHostEndpoint = &cli.StringFlag{
		Name:     "raiko.host.zkvm",
		Usage:    "RPC endpoint of a Raiko ZKVM host service",
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_HOST_ZKVM"},
	}
	RaikoJWTPath = &cli.StringFlag{
		Name:     "raiko.jwtPath",
		Usage:    "Path to a JWT secret for the Raiko service",
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_JWT_PATH"},
	}
	RaikoRequestTimeout = &cli.DurationFlag{
		Name:     "raiko.requestTimeout",
		Usage:    "Timeout in minutes for raiko request",
		Category: commonCategory,
		Value:    10 * time.Minute,
		EnvVars:  []string{"RAIKO_REQUEST_TIMEOUT"},
	}
	StartingBlockID = &cli.Uint64Flag{
		Name:     "prover.startingBlockID",
		Usage:    "If set, prover will start proving blocks from the block with this ID",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_STARTING_BLOCK_ID"},
	}
	Graffiti = &cli.StringFlag{
		Name:     "prover.graffiti",
		Usage:    "When string is passed, adds additional graffiti info to proof evidence",
		Category: proverCategory,
		Value:    "",
		EnvVars:  []string{"PROVER_GRAFFITI"},
	}
	// Proving strategy.
	ProveUnassignedBlocks = &cli.BoolFlag{
		Name:     "prover.proveUnassignedBlocks",
		Usage:    "Whether you want to prove unassigned blocks, or only work on assigned proofs",
		Category: proverCategory,
		Value:    false,
		EnvVars:  []string{"PROVER_PROVE_UNASSIGNED_BLOCKS"},
	}
	// Running mode
	ContesterMode = &cli.BoolFlag{
		Name:     "mode.contester",
		Usage:    "Whether you want to contest wrong transitions with higher tier proofs",
		Category: proverCategory,
		Value:    false,
		EnvVars:  []string{"MODE_CONTESTER"},
	}
	// HTTP server related.
	ProverHTTPServerPort = &cli.Uint64Flag{
		Name:     "prover.port",
		Usage:    "Port to expose for http server",
		Category: proverCategory,
		Value:    9876,
		EnvVars:  []string{"PROVER_PORT"},
	}
	MaxExpiry = &cli.DurationFlag{
		Name:     "http.maxExpiry",
		Usage:    "Maximum accepted expiry in seconds for accepting proving a block",
		Value:    1 * time.Hour,
		Category: proverCategory,
		EnvVars:  []string{"HTTP_MAX_EXPIRY"},
	}
	// Special flags for testing.
	Dummy = &cli.BoolFlag{
		Name:     "prover.dummy",
		Usage:    "Produce dummy proofs, testing purposes only",
		Value:    false,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_DUMMY"},
	}
	// Max amount of L1 blocks that can pass before block is invalid
	Allowance = &cli.Float64Flag{
		Name:     "prover.allowance",
		Usage:    "Amount without decimal to approve TaikoL1 contract for TaikoToken usage",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_ALLOWANCE"},
	}
	GuardianProverHealthCheckServerEndpoint = &cli.StringFlag{
		Name:     "prover.guardianProverHealthCheckServerEndpoint",
		Usage:    "HTTP endpoint for main guardian prover health check server",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_GUARDIAN_PROVER_HEALTH_CHECK_SERVER_ENDPOINT"},
	}
	// Guardian prover specific flag
	GuardianProverMinority = &cli.StringFlag{
		Name:     "guardianProverMinority",
		Usage:    "GuardianProverMinority contract `address`",
		Value:    rpc.ZeroAddress.Hex(),
		Category: proverCategory,
		EnvVars:  []string{"GUARDIAN_PROVER_MINORITY"},
	}
	GuardianProverMajority = &cli.StringFlag{
		Name:     "guardianProverMajority",
		Usage:    "GuardianProverMajority contract `address`",
		Category: proverCategory,
		EnvVars:  []string{"GUARDIAN_PROVER_MAJORITY"},
	}
	GuardianProofSubmissionDelay = &cli.DurationFlag{
		Name:     "guardian.submissionDelay",
		Usage:    "Guardian proof submission delay",
		Value:    1 * time.Hour,
		Category: proverCategory,
		EnvVars:  []string{"GUARDIAN_SUBMISSION_DELAY"},
	}
	EnableLivenessBondProof = &cli.BoolFlag{
		Name:     "prover.enableLivenessBondProof",
		Usage:    "Toggles whether the proof is a dummy proof or returns keccak256(RETURN_LIVENESS_BOND) as proof",
		Value:    false,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_ENABLE_LIVENESS_BOND_PROOF"},
	}
	L1NodeVersion = &cli.StringFlag{
		Name:     "prover.l1NodeVersion",
		Usage:    "Version or tag or the L1 Node Version used as an L1 RPC Url by this guardian prover",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_L1_NODE_VERSION"},
	}
	L2NodeVersion = &cli.StringFlag{
		Name:     "prover.l2NodeVersion",
		Usage:    "Version or tag or the L2 Node Version used as an L2 RPC Url by this guardian prover",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_L2_NODE_VERSION"},
	}
	// Confirmations specific flag
	BlockConfirmations = &cli.Uint64Flag{
		Name:     "prover.blockConfirmations",
		Usage:    "Confirmations to the latest L1 block before submitting a proof for a L2 block",
		Value:    6,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_BLOCK_CONFIRMATIONS"},
	}
	// Batch proof related flag
	SGXBatchSize = &cli.Uint64Flag{
		Name: "prover.sgx.batchSize",
		Usage: "The default size of batch sgx proofs, when it arrives, submit a batch of proof immediately, " +
			"this flag only works post Ontake fork",
		Value:    1,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_SGX_BATCH_SIZE"},
	}
	ZKVMBatchSize = &cli.Uint64Flag{
		Name: "prover.zkvm.batchSize",
		Usage: "The size of batch ZKVM proof, when it arrives, submit a batch of proof immediately, " +
			"this flag only works post Ontake fork",
		Value:    1,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_ZKVM_BATCH_SIZE"},
	}
	ForceBatchProvingInterval = &cli.DurationFlag{
		Name: "prover.forceBatchProvingInterval",
		Usage: "Time interval to prove blocks even the number of pending proof do not exceed prover.batchSize, " +
			"this flag only works post Ontake fork",
		Category: proverCategory,
		Value:    30 * time.Minute,
		EnvVars:  []string{"PROVER_FORCE_BATCH_PROVING_INTERVAL"},
	}
)

// ProverFlags All prover flags.
var ProverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2WSEndpoint,
	L2HTTPEndpoint,
	RaikoHostEndpoint,
	RaikoJWTPath,
	L1ProverPrivKey,
	StartingBlockID,
	Dummy,
	GuardianProverMinority,
	GuardianProverMajority,
	GuardianProofSubmissionDelay,
	GuardianProverHealthCheckServerEndpoint,
	Graffiti,
	ProveUnassignedBlocks,
	ContesterMode,
	ProverHTTPServerPort,
	MaxExpiry,
	TaikoTokenAddress,
	Allowance,
	L1NodeVersion,
	L2NodeVersion,
	BlockConfirmations,
	RaikoRequestTimeout,
	RaikoZKVMHostEndpoint,
	SGXBatchSize,
	ZKVMBatchSize,
	ForceBatchProvingInterval,
}, TxmgrFlags)
