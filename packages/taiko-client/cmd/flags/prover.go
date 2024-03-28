package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// Required flags used by prover.
var (
	L1ProverPrivKey = &cli.StringFlag{
		Name:     "l1.proverPrivKey",
		Usage:    "Private key of L1 prover, who will send TaikoL1.proveBlock transactions",
		Required: true,
		Category: proverCategory,
	}
	ProverCapacity = &cli.Uint64Flag{
		Name:     "prover.capacity",
		Usage:    "Capacity of prover",
		Required: true,
		Category: proverCategory,
	}
	ProverAssignmentHookAddress = &cli.StringFlag{
		Name:     "assignmentHook",
		Usage:    "Address of the AssignmentHook contract",
		Required: true,
		Category: proverCategory,
	}
)

// Optional flags used by prover.
var (
	RaikoHostEndpoint = &cli.StringFlag{
		Name:     "raiko.hostEndpoint",
		Usage:    "RPC endpoint of a Raiko host service",
		Category: proverCategory,
	}
	StartingBlockID = &cli.Uint64Flag{
		Name:     "prover.startingBlockID",
		Usage:    "If set, prover will start proving blocks from the block with this ID",
		Category: proverCategory,
	}
	Graffiti = &cli.StringFlag{
		Name:     "prover.graffiti",
		Usage:    "When string is passed, adds additional graffiti info to proof evidence",
		Category: proverCategory,
		Value:    "",
	}
	// Proving strategy.
	ProveUnassignedBlocks = &cli.BoolFlag{
		Name:     "prover.proveUnassignedBlocks",
		Usage:    "Whether you want to prove unassigned blocks, or only work on assigned proofs",
		Category: proverCategory,
		Value:    false,
	}
	MinEthBalance = &cli.Uint64Flag{
		Name:     "prover.minEthBalance",
		Usage:    "Minimum ETH balance (in wei) a prover wants to keep",
		Category: proverCategory,
		Value:    0,
	}
	MinTaikoTokenBalance = &cli.Uint64Flag{
		Name:     "prover.minTaikoTokenBalance",
		Usage:    "Minimum Taiko token balance a prover wants to keep",
		Category: proverCategory,
		Value:    0,
	}
	// Tier fee related.
	MinOptimisticTierFee = &cli.Uint64Flag{
		Name:     "minTierFee.optimistic",
		Usage:    "Minimum accepted fee for generating an optimistic proof",
		Category: proverCategory,
	}
	MinSgxTierFee = &cli.Uint64Flag{
		Name:     "minTierFee.sgx",
		Usage:    "Minimum accepted fee for generating a SGX proof",
		Category: proverCategory,
	}
	MinSgxAndZkVMTierFee = &cli.Uint64Flag{
		Name:     "minTierFee.sgxAndZkvm",
		Usage:    "Minimum accepted fee for generating a SGX + zkVM proof",
		Category: proverCategory,
	}
	// Guardian prover related.
	GuardianProver = &cli.StringFlag{
		Name:     "guardianProver",
		Usage:    "GuardianProver contract `address`",
		Category: proverCategory,
	}
	GuardianProofSubmissionDelay = &cli.DurationFlag{
		Name:     "guardian.submissionDelay",
		Usage:    "Guardian proof submission delay",
		Value:    0 * time.Second,
		Category: proverCategory,
	}
	// Running mode
	ContesterMode = &cli.BoolFlag{
		Name:     "mode.contester",
		Usage:    "Whether you want to contest wrong transitions with higher tier proofs",
		Category: proverCategory,
		Value:    false,
	}
	// HTTP server related.
	ProverHTTPServerPort = &cli.Uint64Flag{
		Name:     "http.port",
		Usage:    "Port to expose for http server",
		Category: proverCategory,
		Value:    9876,
	}
	MaxExpiry = &cli.DurationFlag{
		Name:     "http.maxExpiry",
		Usage:    "Maximum accepted expiry in seconds for accepting proving a block",
		Value:    1 * time.Hour,
		Category: proverCategory,
	}
	// Special flags for testing.
	Dummy = &cli.BoolFlag{
		Name:     "prover.dummy",
		Usage:    "Produce dummy proofs, testing purposes only",
		Value:    false,
		Category: proverCategory,
	}
	// Max slippage allowed
	MaxAcceptableBlockSlippage = &cli.Uint64Flag{
		Name:     "prover.blockSlippage",
		Usage:    "Maximum accepted slippage difference for blockID for accepting proving a block",
		Value:    1024,
		Category: proverCategory,
	}
	// Max amount of L1 blocks that can pass before block is invalid
	MaxProposedIn = &cli.Uint64Flag{
		Name:     "prover.maxProposedIn",
		Usage:    "Maximum amount of L1 blocks that can pass before block can not be proposed. 0 means no limit.",
		Value:    0,
		Category: proverCategory,
	}
	Allowance = &cli.StringFlag{
		Name:     "prover.allowance",
		Usage:    "Amount to approve AssignmentHook contract for TaikoToken usage",
		Category: proverCategory,
	}
	GuardianProverHealthCheckServerEndpoint = &cli.StringFlag{
		Name:     "prover.guardianProverHealthCheckServerEndpoint",
		Usage:    "HTTP endpoint for main guardian prover health check server",
		Category: proverCategory,
	}
	// Guardian prover specific flag
	EnableLivenessBondProof = &cli.BoolFlag{
		Name:     "prover.enableLivenessBondProof",
		Usage:    "Toggles whether the proof is a dummy proof or returns keccak256(RETURN_LIVENESS_BOND) as proof",
		Value:    false,
		Category: proverCategory,
	}
	L1NodeVersion = &cli.StringFlag{
		Name:     "prover.l1NodeVersion",
		Usage:    "Version or tag or the L1 Node Version used as an L1 RPC Url by this guardian prover",
		Category: proverCategory,
	}
	L2NodeVersion = &cli.StringFlag{
		Name:     "prover.l2NodeVersion",
		Usage:    "Version or tag or the L2 Node Version used as an L2 RPC Url by this guardian prover",
		Category: proverCategory,
	}
	// Confirmations specific flag
	BlockConfirmations = &cli.Uint64Flag{
		Name:     "prover.blockConfirmations",
		Usage:    "Confirmations to the latest l1 block before submitting a proof for a l2 block",
		Value:    6,
		Category: proverCategory,
	}
)

// ProverFlags All prover flags.
var ProverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1HTTPEndpoint,
	L1BeaconEndpoint,
	L2WSEndpoint,
	L2HTTPEndpoint,
	RaikoHostEndpoint,
	L1ProverPrivKey,
	MinOptimisticTierFee,
	MinSgxTierFee,
	MinSgxAndZkVMTierFee,
	MinEthBalance,
	MinTaikoTokenBalance,
	StartingBlockID,
	Dummy,
	GuardianProver,
	GuardianProofSubmissionDelay,
	GuardianProverHealthCheckServerEndpoint,
	Graffiti,
	ProveUnassignedBlocks,
	ContesterMode,
	ProverHTTPServerPort,
	ProverCapacity,
	MaxExpiry,
	MaxProposedIn,
	TaikoTokenAddress,
	MaxAcceptableBlockSlippage,
	ProverAssignmentHookAddress,
	Allowance,
	L1NodeVersion,
	L2NodeVersion,
	BlockConfirmations,
}, TxmgrFlags)
