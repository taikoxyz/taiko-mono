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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Config contains the configurations to initialize a Taiko prover.
type Config struct {
	L1WsEndpoint                            string
	L2WsEndpoint                            string
	L2HttpEndpoint                          string
	TaikoL1Address                          common.Address
	TaikoL2Address                          common.Address
	TaikoTokenAddress                       common.Address
	ProverSetAddress                        common.Address
	L1ProverPrivKey                         *ecdsa.PrivateKey
	StartingBlockID                         *big.Int
	Dummy                                   bool
	GuardianProverMinorityAddress           common.Address
	GuardianProverMajorityAddress           common.Address
	GuardianProofSubmissionDelay            time.Duration
	Graffiti                                string
	BackOffMaxRetries                       uint64
	BackOffRetryInterval                    time.Duration
	ProveUnassignedBlocks                   bool
	ContesterMode                           bool
	EnableLivenessBondProof                 bool
	RPCTimeout                              time.Duration
	ProveBlockGasLimit                      uint64
	HTTPServerPort                          uint64
	Capacity                                uint64
	MinEthBalance                           *big.Int
	MinTaikoTokenBalance                    *big.Int
	MaxExpiry                               time.Duration
	MaxProposedIn                           uint64
	MaxBlockSlippage                        uint64
	Allowance                               *big.Int
	GuardianProverHealthCheckServerEndpoint *url.URL
	RaikoHostEndpoint                       string
	RaikoZKVMHostEndpoint                   string
	RaikoJWT                                string
	RaikoRequestTimeout                     time.Duration
	L1NodeVersion                           string
	L2NodeVersion                           string
	BlockConfirmations                      uint64
	TxmgrConfigs                            *txmgr.CLIConfig
	PrivateTxmgrConfigs                     *txmgr.CLIConfig
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var (
		jwtSecret []byte
	)
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(c.String(flags.L1ProverPrivKey.Name)))
	if err != nil {
		return nil, fmt.Errorf("invalid L1 prover private key: %w", err)
	}

	var startingBlockID *big.Int
	if c.IsSet(flags.StartingBlockID.Name) {
		startingBlockID = new(big.Int).SetUint64(c.Uint64(flags.StartingBlockID.Name))
	}

	var allowance = common.Big0
	if c.IsSet(flags.Allowance.Name) {
		amt, err := utils.EtherToWei(c.Float64(flags.Allowance.Name))
		if err != nil {
			return nil, fmt.Errorf("invalid setting allowance config value: %v", c.Float64(flags.Allowance.Name))
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
	if c.IsSet(flags.GuardianProverMajority.Name) {
		if err := c.Set(flags.ProveUnassignedBlocks.Name, "true"); err != nil {
			return nil, err
		}
		if err := c.Set(flags.ContesterMode.Name, "true"); err != nil {
			return nil, err
		}

		// L1 and L2 node version flags are required only if guardian prover
		if !c.IsSet(flags.L1NodeVersion.Name) {
			return nil, errors.New("--prover.l1NodeVersion flag is required if guardian prover is set")
		}
		if !c.IsSet(flags.L2NodeVersion.Name) {
			return nil, errors.New("--prover.l2NodeVersion flag is required if guardian prover is set")
		}
	}

	minEthBalance, err := utils.EtherToWei(c.Float64(flags.MinEthBalance.Name))
	if err != nil {
		return nil, err
	}

	minTaikoTokenBalance, err := utils.EtherToWei(c.Float64(flags.MinTaikoTokenBalance.Name))
	if err != nil {
		return nil, err
	}

	if !c.IsSet(flags.GuardianProverMajority.Name) && !c.IsSet(flags.RaikoHostEndpoint.Name) {
		return nil, errors.New("empty raiko host endpoint")
	}

	if c.IsSet(flags.RaikoJWTPath.Name) {
		jwtSecret, err = jwt.ParseSecretFromFile(c.String(flags.RaikoJWTPath.Name))
		if err != nil {
			return nil, fmt.Errorf("invalid JWT secret file: %w", err)
		}
	}

	return &Config{
		L1WsEndpoint:                            c.String(flags.L1WSEndpoint.Name),
		L2WsEndpoint:                            c.String(flags.L2WSEndpoint.Name),
		L2HttpEndpoint:                          c.String(flags.L2HTTPEndpoint.Name),
		TaikoL1Address:                          common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
		TaikoL2Address:                          common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
		TaikoTokenAddress:                       common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
		ProverSetAddress:                        common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
		L1ProverPrivKey:                         l1ProverPrivKey,
		RaikoHostEndpoint:                       c.String(flags.RaikoHostEndpoint.Name),
		RaikoZKVMHostEndpoint:                   c.String(flags.RaikoZKVMHostEndpoint.Name),
		RaikoJWT:                                common.Bytes2Hex(jwtSecret),
		RaikoRequestTimeout:                     c.Duration(flags.RaikoRequestTimeout.Name),
		StartingBlockID:                         startingBlockID,
		Dummy:                                   c.Bool(flags.Dummy.Name),
		GuardianProverMinorityAddress:           common.HexToAddress(c.String(flags.GuardianProverMinority.Name)),
		GuardianProverMajorityAddress:           common.HexToAddress(c.String(flags.GuardianProverMajority.Name)),
		GuardianProofSubmissionDelay:            c.Duration(flags.GuardianProofSubmissionDelay.Name),
		GuardianProverHealthCheckServerEndpoint: guardianProverHealthCheckServerEndpoint,
		Graffiti:                                c.String(flags.Graffiti.Name),
		BackOffMaxRetries:                       c.Uint64(flags.BackOffMaxRetries.Name),
		BackOffRetryInterval:                    c.Duration(flags.BackOffRetryInterval.Name),
		ProveUnassignedBlocks:                   c.Bool(flags.ProveUnassignedBlocks.Name),
		ContesterMode:                           c.Bool(flags.ContesterMode.Name),
		EnableLivenessBondProof:                 c.Bool(flags.EnableLivenessBondProof.Name),
		RPCTimeout:                              c.Duration(flags.RPCTimeout.Name),
		ProveBlockGasLimit:                      c.Uint64(flags.TxGasLimit.Name),
		Capacity:                                c.Uint64(flags.ProverCapacity.Name),
		HTTPServerPort:                          c.Uint64(flags.ProverHTTPServerPort.Name),
		MinEthBalance:                           minEthBalance,
		MinTaikoTokenBalance:                    minTaikoTokenBalance,
		MaxExpiry:                               c.Duration(flags.MaxExpiry.Name),
		MaxBlockSlippage:                        c.Uint64(flags.MaxAcceptableBlockSlippage.Name),
		MaxProposedIn:                           c.Uint64(flags.MaxProposedIn.Name),
		Allowance:                               allowance,
		L1NodeVersion:                           c.String(flags.L1NodeVersion.Name),
		L2NodeVersion:                           c.String(flags.L2NodeVersion.Name),
		BlockConfirmations:                      c.Uint64(flags.BlockConfirmations.Name),
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1WSEndpoint.Name),
			l1ProverPrivKey,
			c,
		),
		PrivateTxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1PrivateEndpoint.Name),
			l1ProverPrivKey,
			c,
		),
	}, nil
}
