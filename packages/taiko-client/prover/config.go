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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Config contains the configurations to initialize a Taiko prover.
type Config struct {
	L1HttpEndpoint            string
	L2WsEndpoint              string
	L2HttpEndpoint            string
	PacayaInboxAddress        common.Address
	ShastaInboxAddress        common.Address
	TaikoAnchorAddress        common.Address
	TaikoTokenAddress         common.Address
	ProverSetAddress          common.Address
	ShastaForkTime            uint64
	L1ProverPrivKey           *ecdsa.PrivateKey
	StartingBatchID           *big.Int
	BackOffMaxRetries         uint64
	BackOffRetryInterval      time.Duration
	ProveUnassignedBlocks     bool
	RPCTimeout                time.Duration
	ProveBatchesGasLimit      uint64
	Allowance                 *big.Int
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

	var startingBatchID *big.Int
	if c.IsSet(flags.StartingBatchID.Name) {
		startingBatchID = new(big.Int).SetUint64(c.Uint64(flags.StartingBatchID.Name))
	}

	var allowance = common.Big0
	if c.IsSet(flags.Allowance.Name) {
		amt, err := utils.EtherToWei(c.Float64(flags.Allowance.Name))
		if err != nil {
			return nil, fmt.Errorf("invalid setting allowance config value: %v", c.Float64(flags.Allowance.Name))
		}

		allowance = amt
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

	return &Config{
		L1HttpEndpoint:         c.String(flags.L1HTTPEndpoint.Name),
		L2WsEndpoint:           c.String(flags.L2WSEndpoint.Name),
		L2HttpEndpoint:         c.String(flags.L2HTTPEndpoint.Name),
		PacayaInboxAddress:     common.HexToAddress(c.String(flags.PacayaInboxAddress.Name)),
		ShastaInboxAddress:     common.HexToAddress(c.String(flags.ShastaInboxAddress.Name)),
		TaikoAnchorAddress:     common.HexToAddress(c.String(flags.TaikoAnchorAddress.Name)),
		TaikoTokenAddress:      common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
		ProverSetAddress:       common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
		ShastaForkTime:         c.Uint64(flags.ShastaForkTime.Name),
		L1ProverPrivKey:        l1ProverPrivKey,
		RaikoHostEndpoint:      c.String(flags.RaikoHostEndpoint.Name),
		RaikoZKVMHostEndpoint:  c.String(flags.RaikoZKVMHostEndpoint.Name),
		RaikoApiKey:            strings.TrimSpace(string(raikoApiKey)),
		RaikoRequestTimeout:    c.Duration(flags.RaikoRequestTimeout.Name),
		StartingBatchID:        startingBatchID,
		Dummy:                  c.Bool(flags.Dummy.Name),
		BackOffMaxRetries:      c.Uint64(flags.BackOffMaxRetries.Name),
		BackOffRetryInterval:   c.Duration(flags.BackOffRetryInterval.Name),
		ProveUnassignedBlocks:  c.Bool(flags.ProveUnassignedBlocks.Name),
		RPCTimeout:             c.Duration(flags.RPCTimeout.Name),
		ProveBatchesGasLimit:   c.Uint64(flags.TxGasLimit.Name),
		Allowance:              allowance,
		LocalProposerAddresses: localProposerAddresses,
		BlockConfirmations:     c.Uint64(flags.BlockConfirmations.Name),
		TxmgrConfigs:           pkgFlags.InitTxmgrConfigsFromCli(c.String(flags.L1HTTPEndpoint.Name), l1ProverPrivKey, c),
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
