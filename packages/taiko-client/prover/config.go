package prover

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/prysmaticlabs/prysm/v5/io/file"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
)

// Config contains the configurations to initialize a Taiko prover.
type Config struct {
	L1WsEndpoint              string
	L1BeaconEndpoint          string
	L2WsEndpoint              string
	L2HttpEndpoint            string
	L2EngineEndpoint          string
	JwtSecret                 string
	InboxAddress              common.Address
	TaikoAnchorAddress        common.Address
	L1ProverPrivKey           *ecdsa.PrivateKey
	StartingProposalID        *big.Int
	BackOffMaxRetries         uint64
	BackOffRetryInterval      time.Duration
	ProveUnassignedProposals  bool
	RPCTimeout                time.Duration
	ProveBatchesGasLimit      uint64
	RaikoHostEndpoint         string
	RaikoZKVMHostEndpoint     string
	RaikoApiKey               string
	RaikoRequestTimeout       time.Duration
	LocalProposerAddresses    []common.Address
	BlockConfirmations        uint64
	TxmgrConfigs              *txmgr.CLIConfig
	PrivateTxmgrConfigs       *txmgr.CLIConfig
	SGXProofBufferSize        uint64
	ZKVMProofBufferSize       uint64
	ForceBatchProvingInterval time.Duration
	ProofPollingInterval      time.Duration
	Dummy                     bool
	ProposalWindowSize        uint64
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	var (
		raikoApiKey []byte
	)
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(c.String(flags.L1ProverPrivKey.Name)))
	if err != nil {
		return nil, fmt.Errorf("invalid L1 prover private key: %w", err)
	}

	jwtSecret, err := jwt.ParseSecretFromFile(c.String(flags.JWTSecret.Name))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT secret file: %w", err)
	}

	var startingProposalID *big.Int
	if c.IsSet(flags.StartingProposalID.Name) {
		startingProposalID = new(big.Int).SetUint64(c.Uint64(flags.StartingProposalID.Name))
	}

	if c.IsSet(flags.RaikoApiKeyPath.Name) {
		raikoApiKey, err = file.ReadFileAsBytes(c.String(flags.RaikoApiKeyPath.Name))
		if err != nil {
			return nil, fmt.Errorf("invalid ApiKey secret file: %w", err)
		}
	}

	var localProposerAddresses []common.Address
	for _, localProposerAddress := range c.StringSlice(flags.LocalProposerAddresses.Name) {
		if !common.IsHexAddress(localProposerAddress) {
			log.Debug("Invalid local proposer address", "address", localProposerAddress)
			continue
		}
		addr := common.HexToAddress(localProposerAddress)
		localProposerAddresses = append(localProposerAddresses, addr)
	}
	log.Info("Local proposer addresses", "addresses", localProposerAddresses)

	l1WsEndpoint, err := requiredEndpoint(c, flags.L1WSEndpoint.Name)
	if err != nil {
		return nil, err
	}
	l2WsEndpoint, err := requiredEndpoint(c, flags.L2WSEndpoint.Name)
	if err != nil {
		return nil, err
	}
	l2HttpEndpoint, err := requiredEndpoint(c, flags.L2HTTPEndpoint.Name)
	if err != nil {
		return nil, err
	}

	return &Config{
		L1WsEndpoint:             l1WsEndpoint,
		L1BeaconEndpoint:         c.String(flags.L1BeaconEndpoint.Name),
		L2WsEndpoint:             l2WsEndpoint,
		L2HttpEndpoint:           l2HttpEndpoint,
		L2EngineEndpoint:         c.String(flags.L2AuthEndpoint.Name),
		JwtSecret:                string(jwtSecret),
		InboxAddress:             common.HexToAddress(c.String(flags.InboxAddress.Name)),
		TaikoAnchorAddress:       common.HexToAddress(c.String(flags.TaikoAnchorAddress.Name)),
		L1ProverPrivKey:          l1ProverPrivKey,
		RaikoHostEndpoint:        c.String(flags.RaikoHostEndpoint.Name),
		RaikoZKVMHostEndpoint:    c.String(flags.RaikoZKVMHostEndpoint.Name),
		RaikoApiKey:              strings.TrimSpace(string(raikoApiKey)),
		RaikoRequestTimeout:      c.Duration(flags.RaikoRequestTimeout.Name),
		StartingProposalID:       startingProposalID,
		Dummy:                    c.Bool(flags.Dummy.Name),
		BackOffMaxRetries:        c.Uint64(flags.BackOffMaxRetries.Name),
		BackOffRetryInterval:     c.Duration(flags.BackOffRetryInterval.Name),
		ProveUnassignedProposals: c.Bool(flags.ProveUnassignedProposals.Name),
		ProposalWindowSize:       c.Uint64(flags.ProposalWindowSize.Name),
		RPCTimeout:               c.Duration(flags.RPCTimeout.Name),
		ProveBatchesGasLimit:     c.Uint64(flags.TxGasLimit.Name),
		LocalProposerAddresses:   localProposerAddresses,
		BlockConfirmations:       c.Uint64(flags.BlockConfirmations.Name),
		TxmgrConfigs:             pkgFlags.InitTxmgrConfigsFromCli(l1WsEndpoint, l1ProverPrivKey, c),
		PrivateTxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1PrivateEndpoint.Name),
			l1ProverPrivKey,
			c,
		),
		SGXProofBufferSize:        c.Uint64(flags.SGXBatchSize.Name),
		ZKVMProofBufferSize:       c.Uint64(flags.ZKVMBatchSize.Name),
		ForceBatchProvingInterval: c.Duration(flags.ForceBatchProvingInterval.Name),
		ProofPollingInterval:      c.Duration(flags.ProofPollingInterval.Name),
	}, nil
}

// requiredEndpoint returns a trimmed required endpoint value from the CLI context.
func requiredEndpoint(c *cli.Context, name string) (string, error) {
	endpoint := strings.TrimSpace(c.String(name))
	if endpoint == "" {
		return "", fmt.Errorf("empty %s endpoint", name)
	}
	return endpoint, nil
}
