package proposer

import (
	"crypto/ecdsa"
	"fmt"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
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
	MinProposingInternal    time.Duration
	AllowZeroTipInterval    uint64
	MaxTxListsPerEpoch      uint64
	ProposeBatchTxGasLimit  uint64
	BlobAllowed             bool
	FallbackToCalldata      bool
	RevertProtectionEnabled bool
	TxmgrConfigs            *txmgr.CLIConfig
	PrivateTxmgrConfigs     *txmgr.CLIConfig
	FallbackTimeout         time.Duration
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

	return &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  c.String(flags.L1WSEndpoint.Name),
			L2Endpoint:                  c.String(flags.L2WSEndpoint.Name),
			PacayaInboxAddress:          common.HexToAddress(c.String(flags.PacayaInboxAddress.Name)),
			ShastaInboxAddress:          common.HexToAddress(c.String(flags.ShastaInboxAddress.Name)),
			TaikoWrapperAddress:         common.HexToAddress(c.String(flags.TaikoWrapperAddress.Name)),
			ForcedInclusionStoreAddress: common.HexToAddress(c.String(flags.ForcedInclusionStoreAddress.Name)),
			TaikoAnchorAddress:          common.HexToAddress(c.String(flags.TaikoAnchorAddress.Name)),
			L2EngineEndpoint:            c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:                   string(jwtSecret),
			TaikoTokenAddress:           common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
			Timeout:                     c.Duration(flags.RPCTimeout.Name),
			ProverSetAddress:            common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
			ShastaForkTime:              c.Uint64(flags.ShastaForkTime.Name),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(l2SuggestedFeeRecipient),
		ProposeInterval:         c.Duration(flags.ProposeInterval.Name),
		MinTip:                  minTip.Uint64(),
		MinProposingInternal:    c.Duration(flags.MinProposingInternal.Name),
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
		FallbackTimeout: c.Duration(flags.FallbackTimeout.Name),
	}, nil
}
