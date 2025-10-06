package proposer

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Config contains all configurations to initialize a Taiko proposer.
type Config struct {
	*rpc.ClientConfig
	L1ProposerPrivKey       *ecdsa.PrivateKey
	L2SuggestedFeeRecipient common.Address
	ProposeInterval         time.Duration
	MinTip                  uint64
	MinProposingInterval    time.Duration
	ForceProposingDelay     time.Duration
	AllowZeroTipInterval    uint64
	MaxTxListsPerEpoch      uint64
	ProposeBatchTxGasLimit  uint64
	BlobAllowed             bool
	FallbackToCalldata      bool
	RevertProtectionEnabled bool
	CheckProfitability      bool
	TxmgrConfigs            *txmgr.CLIConfig
	PrivateTxmgrConfigs     *txmgr.CLIConfig

	// L2 cost estimation parameters
	ProvingCostPerL2Batch       *big.Int
	BatchPostingGasWithCalldata uint64
	BatchPostingGasWithBlobs    uint64
	ProofPostingGas             uint64
}

// NewConfigFromCliContext initializes a Config instance from
// command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	jwtSecret, err := jwt.ParseSecretFromFile(c.String(flags.JWTSecret.Name))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT secret file: %w", err)
	}

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(c.String(flags.L1ProposerPrivKey.Name)))
	if err != nil {
		return nil, fmt.Errorf("invalid L1 proposer private key: %w", err)
	}

	l2SuggestedFeeRecipient := c.String(flags.L2SuggestedFeeRecipient.Name)
	if !common.IsHexAddress(l2SuggestedFeeRecipient) {
		return nil, fmt.Errorf("invalid L2 suggested fee recipient address: %s", l2SuggestedFeeRecipient)
	}

	minTip, err := utils.GWeiToWei(c.Float64(flags.MinTip.Name))
	if err != nil {
		return nil, err
	}

	maxTxListsPerEpoch := c.Uint64(flags.MaxTxListsPerEpoch.Name)
	if maxTxListsPerEpoch > eth.MaxBlobsPerBlobTx {
		return nil, fmt.Errorf("max proposed tx lists per epoch should not exceed %d, got: %d",
			eth.MaxBlobsPerBlobTx,
			maxTxListsPerEpoch,
		)
	}
	log.Info("Proposer maxTxListsPerEpoch", "value", maxTxListsPerEpoch)

	// Default L2 cost estimation parameters
	provingCostPerL2Batch := big.NewInt(800_000_000_000_000) // 8 * 10^14 Wei
	batchPostingGasWithCalldata := uint64(260_000)
	batchPostingGasWithBlobs := uint64(160_000)
	proofPostingGas := uint64(750_000)

	return &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  c.String(flags.L1WSEndpoint.Name),
			L2Endpoint:                  c.String(flags.L2HTTPEndpoint.Name),
			TaikoInboxAddress:           common.HexToAddress(c.String(flags.TaikoInboxAddress.Name)),
			TaikoWrapperAddress:         common.HexToAddress(c.String(flags.TaikoWrapperAddress.Name)),
			ForcedInclusionStoreAddress: common.HexToAddress(c.String(flags.ForcedInclusionStoreAddress.Name)),
			TaikoAnchorAddress:          common.HexToAddress(c.String(flags.TaikoAnchorAddress.Name)),
			L2EngineEndpoint:            c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:                   string(jwtSecret),
			TaikoTokenAddress:           common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
			Timeout:                     c.Duration(flags.RPCTimeout.Name),
			ProverSetAddress:            common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
			BridgeAddress:               common.HexToAddress(c.String(flags.BridgeAddress.Name)),
			SurgeProposerWrapperAddress: common.HexToAddress(c.String(flags.SurgeProposerWrapperAddress.Name)),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(l2SuggestedFeeRecipient),
		ProposeInterval:         c.Duration(flags.ProposeInterval.Name),
		MinTip:                  minTip.Uint64(),
		MinProposingInterval:    c.Duration(flags.MinProposingInterval.Name),
		ForceProposingDelay:     c.Duration(flags.ForceProposingDelay.Name),
		MaxTxListsPerEpoch:      maxTxListsPerEpoch,
		AllowZeroTipInterval:    c.Uint64(flags.AllowZeroTipInterval.Name),
		ProposeBatchTxGasLimit:  c.Uint64(flags.TxGasLimit.Name),
		BlobAllowed:             c.Bool(flags.BlobAllowed.Name),
		FallbackToCalldata:      c.Bool(flags.FallbackToCalldata.Name),
		RevertProtectionEnabled: c.Bool(flags.RevertProtectionEnabled.Name),
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1WSEndpoint.Name),
			l1ProposerPrivKey,
			c,
		),
		PrivateTxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.L1PrivateEndpoint.Name),
			l1ProposerPrivKey,
			c,
		),
		CheckProfitability:          c.Bool(flags.CheckProfitability.Name),
		ProvingCostPerL2Batch:       provingCostPerL2Batch,
		BatchPostingGasWithCalldata: batchPostingGasWithCalldata,
		BatchPostingGasWithBlobs:    batchPostingGasWithBlobs,
		ProofPostingGas:             proofPostingGas,
	}, nil
}
