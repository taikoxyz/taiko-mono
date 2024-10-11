package stress

import (
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
)

// Config contains the configurations to initialize a Taiko prover.
type Config struct {
	L1WsEndpoint          string
	L2WsEndpoint          string
	L2HttpEndpoint        string
	TaikoL1Address        common.Address
	TaikoL2Address        common.Address
	ProverSetAddress      common.Address
	StartingBlockID       *big.Int
	EndingBlockID         *big.Int
	ProveTimeout          time.Duration
	Dummy                 bool
	Graffiti              string
	BackOffMaxRetries     uint64
	BackOffRetryInterval  time.Duration
	RPCTimeout            time.Duration
	HTTPServerPort        uint64
	Capacity              uint64
	RaikoHostEndpoint     string
	RaikoZKVMHostEndpoint string
	RaikoJWT              string
	RaikoRequestTimeout   time.Duration
	L1NodeVersion         string
	L2NodeVersion         string
	ZkType                string
	DBPath                string
	LogPath               string
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var (
		jwtSecret []byte
		err       error
	)

	var startingBlockID *big.Int
	if c.IsSet(flags.StressStartingBlockID.Name) {
		startingBlockID = new(big.Int).SetUint64(c.Uint64(flags.StressStartingBlockID.Name))
	}

	var endingBlockID *big.Int
	if c.IsSet(flags.StressEndingBlockID.Name) {
		endingBlockID = new(big.Int).SetUint64(c.Uint64(flags.StressEndingBlockID.Name))
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
		L1WsEndpoint:          c.String(flags.L1WSEndpoint.Name),
		L2WsEndpoint:          c.String(flags.L2WSEndpoint.Name),
		L2HttpEndpoint:        c.String(flags.L2HTTPEndpoint.Name),
		TaikoL1Address:        common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
		TaikoL2Address:        common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
		ProverSetAddress:      common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
		RaikoHostEndpoint:     c.String(flags.RaikoHostEndpoint.Name),
		RaikoZKVMHostEndpoint: c.String(flags.RaikoZKVMHostEndpoint.Name),
		RaikoJWT:              common.Bytes2Hex(jwtSecret),
		RaikoRequestTimeout:   c.Duration(flags.RaikoRequestTimeout.Name),
		StartingBlockID:       startingBlockID,
		EndingBlockID:         endingBlockID,
		Dummy:                 c.Bool(flags.Dummy.Name),
		Graffiti:              c.String(flags.Graffiti.Name),
		BackOffMaxRetries:     c.Uint64(flags.BackOffMaxRetries.Name),
		BackOffRetryInterval:  c.Duration(flags.BackOffRetryInterval.Name),
		RPCTimeout:            c.Duration(flags.RPCTimeout.Name),
		Capacity:              c.Uint64(flags.ProverCapacity.Name),
		HTTPServerPort:        c.Uint64(flags.ProverHTTPServerPort.Name),
		L1NodeVersion:         c.String(flags.L1NodeVersion.Name),
		L2NodeVersion:         c.String(flags.L2NodeVersion.Name),
		ZkType:                c.String(flags.StressZkType.Name),
		DBPath:                c.String(flags.StressDBPath.Name),
		LogPath:               c.String(flags.StressLogPath.Name),
	}, nil
}
