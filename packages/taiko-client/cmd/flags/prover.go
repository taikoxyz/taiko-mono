package flags

import (
	"time"

	opsigner "github.com/ethereum-optimism/optimism/op-service/signer"
	"github.com/urfave/cli/v2"
)

// Required flags used by prover.
var (
	L1ProverPrivKey = &cli.StringFlag{
		Name:     "l1.proverPrivKey",
		Usage:    "Private key of L1 prover, who will send transactions to Pacaya / Shasta inbox",
		Required: true,
		Category: proverCategory,
		EnvVars:  []string{"L1_PROVER_PRIV_KEY"},
	}
	RaikoHostEndpoint = &cli.StringFlag{
		Name:     "raiko.host",
		Usage:    "RPC endpoint of a Raiko host service",
		Required: true,
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_HOST"},
	}
)

// Optional flags used by prover.
var (
	RaikoZKVMHostEndpoint = &cli.StringFlag{
		Name:     "raiko.host.zkvm",
		Usage:    "RPC endpoint of a Raiko ZKVM host service",
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_HOST_ZKVM"},
	}
	RaikoApiKeyPath = &cli.StringFlag{
		Name:     "raiko.apiKeyPath",
		Usage:    "Path to an Api key for the Raiko service",
		Category: proverCategory,
		EnvVars:  []string{"RAIKO_API_KEY_PATH"},
	}
	RaikoRequestTimeout = &cli.DurationFlag{
		Name:     "raiko.requestTimeout",
		Usage:    "Timeout in minutes for raiko request",
		Category: commonCategory,
		Value:    10 * time.Minute,
		EnvVars:  []string{"RAIKO_REQUEST_TIMEOUT"},
	}
	StartingBatchID = &cli.Uint64Flag{
		Name:     "prover.startingBatchID",
		Usage:    "If set, prover will start proving batches from the batch with this ID",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_STARTING_BATCH_ID"},
	}
	// Proving strategy.
	ProveUnassignedBlocks = &cli.BoolFlag{
		Name:     "prover.proveUnassignedBlocks",
		Usage:    "Whether you want to prove unassigned blocks, or only work on assigned proofs",
		Category: proverCategory,
		Value:    false,
		EnvVars:  []string{"PROVER_PROVE_UNASSIGNED_BLOCKS"},
	}
	// Special flags for testing.
	Dummy = &cli.BoolFlag{
		Name:     "prover.dummy",
		Usage:    "Produce dummy proofs, testing purposes only",
		Value:    false,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_DUMMY"},
	}
	Allowance = &cli.Float64Flag{
		Name:     "prover.allowance",
		Usage:    "Amount without decimal to approve TaikoInbox contract for TaikoToken usage",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_ALLOWANCE"},
	}
	ProofPollingInterval = &cli.DurationFlag{
		Name:     "prover.proofPollingInterval",
		Usage:    "Time interval to poll proofs from raiko host",
		Category: proverCategory,
		Value:    10 * time.Second,
		EnvVars:  []string{"PROVER_PROOF_POLLING_INTERVAL"},
	}
	LocalProposerAddresses = &cli.StringSliceFlag{
		Name: "prover.localProposerAddresses",
		Usage: "Comma separated list of local proposer addresses, " +
			"if set, prover will prove the batches proposed by these addresses before the assignment expiration time",
		Category: proverCategory,
		EnvVars:  []string{"PROVER_LOCAL_PROPOSER_ADDRESSES"},
	}
	// Confirmations specific flag
	BlockConfirmations = &cli.Uint64Flag{
		Name:     "prover.blockConfirmations",
		Usage:    "Confirmations to the latest L1 block before submitting a proof for a L2 block",
		Value:    6,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_BLOCK_CONFIRMATIONS"},
	}
	ForceBatchProvingInterval = &cli.DurationFlag{
		Name: "prover.forceBatchProvingInterval",
		Usage: "Time interval to prove blocks even if the number of pending proofs does not exceed prover.batchSize, " +
			"this flag only works for post Ontake fork blocks",
		Category: proverCategory,
		Value:    30 * time.Minute,
		EnvVars:  []string{"PROVER_FORCE_BATCH_PROVING_INTERVAL"},
	}
	// Batch proof related flag
	SGXBatchSize = &cli.Uint64Flag{
		Name: "prover.sgx.batchSize",
		Usage: "The default size of batch sgx proofs, when it arrives, submit a batch of proofs immediately, " +
			"this flag only works for post Ontake fork blocks",
		Value:    1,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_SGX_BATCH_SIZE"},
	}
	ZKVMBatchSize = &cli.Uint64Flag{
		Name: "prover.zkvm.batchSize",
		Usage: "The size of batch ZKVM proof, when it arrives, submit a batch of proofs immediately, " +
			"this flag only works for post Ontake fork blocks",
		Value:    1,
		Category: proverCategory,
		EnvVars:  []string{"PROVER_ZKVM_BATCH_SIZE"},
	}
)

// ProverFlags All prover flags.
var ProverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2WSEndpoint,
	L2HTTPEndpoint,
	RaikoHostEndpoint,
	RaikoApiKeyPath,
	L1ProverPrivKey,
	StartingBatchID,
	Dummy,
	ProveUnassignedBlocks,
	TaikoTokenAddress,
	Allowance,
	ProofPollingInterval,
	LocalProposerAddresses,
	BlockConfirmations,
	RaikoRequestTimeout,
	RaikoZKVMHostEndpoint,
	SGXBatchSize,
	ZKVMBatchSize,
	ForceBatchProvingInterval,
}, opsigner.CLIFlags("PROVER", proverCategory), TxmgrFlags)
