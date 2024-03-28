package prover

import (
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"net/url"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-client/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-client/pkg/flags"
)

// Config contains the configurations to initialize a Taiko prover.
type Config struct {
	L1WsEndpoint                            string
	L1HttpEndpoint                          string
	L1BeaconEndpoint                        string
	L2WsEndpoint                            string
	L2HttpEndpoint                          string
	TaikoL1Address                          common.Address
	TaikoL2Address                          common.Address
	TaikoTokenAddress                       common.Address
	AssignmentHookAddress                   common.Address
	L1ProverPrivKey                         *ecdsa.PrivateKey
	StartingBlockID                         *big.Int
	Dummy                                   bool
	GuardianProverAddress                   common.Address
	GuardianProofSubmissionDelay            time.Duration
	Graffiti                                string
	BackOffMaxRetrys                        uint64
	BackOffRetryInterval                    time.Duration
	ProveUnassignedBlocks                   bool
	ContesterMode                           bool
	EnableLivenessBondProof                 bool
	RPCTimeout                              time.Duration
	WaitReceiptTimeout                      time.Duration
	ProveBlockGasLimit                      *uint64
	HTTPServerPort                          uint64
	Capacity                                uint64
	MinOptimisticTierFee                    *big.Int
	MinSgxTierFee                           *big.Int
	MinSgxAndZkVMTierFee                    *big.Int
	MinEthBalance                           *big.Int
	MinTaikoTokenBalance                    *big.Int
	MaxExpiry                               time.Duration
	MaxProposedIn                           uint64
	MaxBlockSlippage                        uint64
	Allowance                               *big.Int
	GuardianProverHealthCheckServerEndpoint *url.URL
	RaikoHostEndpoint                       string
	L1NodeVersion                           string
	L2NodeVersion                           string
	BlockConfirmations                      uint64
	TxmgrConfigs                            *txmgr.CLIConfig
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(c.String(flags.L1ProverPrivKey.Name)))
	if err != nil {
		return nil, fmt.Errorf("invalid L1 prover private key: %w", err)
	}

	if !c.IsSet(flags.L1BeaconEndpoint.Name) {
		return nil, errors.New("empty L1 beacon endpoint")
	}

	var startingBlockID *big.Int
	if c.IsSet(flags.StartingBlockID.Name) {
		startingBlockID = new(big.Int).SetUint64(c.Uint64(flags.StartingBlockID.Name))
	}

	var proveBlockTxGasLimit *uint64
	if c.IsSet(flags.TxGasLimit.Name) {
		gasLimit := c.Uint64(flags.TxGasLimit.Name)
		proveBlockTxGasLimit = &gasLimit
	}

	var allowance = common.Big0
	if c.IsSet(flags.Allowance.Name) {
		amt, ok := new(big.Int).SetString(c.String(flags.Allowance.Name), 10)
		if !ok {
			return nil, fmt.Errorf("invalid setting allowance config value: %v", c.String(flags.Allowance.Name))
		}

		allowance = amt
	}

	var guardianProverHealthCheckServerEndpoint *url.URL
	if c.IsSet(flags.GuardianProverHealthCheckServerEndpoint.Name) {
		if guardianProverHealthCheckServerEndpoint, err = url.Parse(
			c.String(flags.GuardianProverHealthCheckServerEndpoint.Name),
		); err != nil {
			return nil, err
		}
	}

	// If we are running a guardian prover, we need to prove unassigned blocks and run in contester mode by default.
	if c.IsSet(flags.GuardianProver.Name) {
		if err := c.Set(flags.ProveUnassignedBlocks.Name, "true"); err != nil {
			return nil, err
		}

		if err := c.Set(flags.ContesterMode.Name, "true"); err != nil {
			return nil, err
		}

		// l1 and l2 node version flags are required only if guardian prover
		if !c.IsSet(flags.L1NodeVersion.Name) {
			return nil, errors.New("L1NodeVersion is required if guardian prover is set")
		}

		if !c.IsSet(flags.L2NodeVersion.Name) {
			return nil, errors.New("L2NodeVersion is required if guardian prover is set")
		}
	}

	if !c.IsSet(flags.GuardianProver.Name) && !c.IsSet(flags.RaikoHostEndpoint.Name) {
		return nil, fmt.Errorf("raiko host not provided")
	}

	return &Config{
		L1WsEndpoint:                            c.String(flags.L1WSEndpoint.Name),
		L1HttpEndpoint:                          c.String(flags.L1HTTPEndpoint.Name),
		L1BeaconEndpoint:                        c.String(flags.L1BeaconEndpoint.Name),
		L2WsEndpoint:                            c.String(flags.L2WSEndpoint.Name),
		L2HttpEndpoint:                          c.String(flags.L2HTTPEndpoint.Name),
		TaikoL1Address:                          common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
		TaikoL2Address:                          common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
		TaikoTokenAddress:                       common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
		AssignmentHookAddress:                   common.HexToAddress(c.String(flags.ProverAssignmentHookAddress.Name)),
		L1ProverPrivKey:                         l1ProverPrivKey,
		RaikoHostEndpoint:                       c.String(flags.RaikoHostEndpoint.Name),
		StartingBlockID:                         startingBlockID,
		Dummy:                                   c.Bool(flags.Dummy.Name),
		GuardianProverAddress:                   common.HexToAddress(c.String(flags.GuardianProver.Name)),
		GuardianProofSubmissionDelay:            c.Duration(flags.GuardianProofSubmissionDelay.Name),
		GuardianProverHealthCheckServerEndpoint: guardianProverHealthCheckServerEndpoint,
		Graffiti:                                c.String(flags.Graffiti.Name),
		BackOffMaxRetrys:                        c.Uint64(flags.BackOffMaxRetrys.Name),
		BackOffRetryInterval:                    c.Duration(flags.BackOffRetryInterval.Name),
		ProveUnassignedBlocks:                   c.Bool(flags.ProveUnassignedBlocks.Name),
		ContesterMode:                           c.Bool(flags.ContesterMode.Name),
		EnableLivenessBondProof:                 c.Bool(flags.EnableLivenessBondProof.Name),
		RPCTimeout:                              c.Duration(flags.RPCTimeout.Name),
		WaitReceiptTimeout:                      c.Duration(flags.WaitReceiptTimeout.Name),
		ProveBlockGasLimit:                      proveBlockTxGasLimit,
		Capacity:                                c.Uint64(flags.ProverCapacity.Name),
		HTTPServerPort:                          c.Uint64(flags.ProverHTTPServerPort.Name),
		MinOptimisticTierFee:                    new(big.Int).SetUint64(c.Uint64(flags.MinOptimisticTierFee.Name)),
		MinSgxTierFee:                           new(big.Int).SetUint64(c.Uint64(flags.MinSgxTierFee.Name)),
		MinSgxAndZkVMTierFee:                    new(big.Int).SetUint64(c.Uint64(flags.MinSgxAndZkVMTierFee.Name)),
		MinEthBalance:                           new(big.Int).SetUint64(c.Uint64(flags.MinEthBalance.Name)),
		MinTaikoTokenBalance:                    new(big.Int).SetUint64(c.Uint64(flags.MinTaikoTokenBalance.Name)),
		MaxExpiry:                               c.Duration(flags.MaxExpiry.Name),
		MaxBlockSlippage:                        c.Uint64(flags.MaxAcceptableBlockSlippage.Name),
		MaxProposedIn:                           c.Uint64(flags.MaxProposedIn.Name),
		Allowance:                               allowance,
		L1NodeVersion:                           c.String(flags.L1NodeVersion.Name),
		L2NodeVersion:                           c.String(flags.L2NodeVersion.Name),
		BlockConfirmations:                      c.Uint64(flags.BlockConfirmations.Name),
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1HTTPEndpoint.Name),
			l1ProverPrivKey,
			c,
		),
	}, nil
}
