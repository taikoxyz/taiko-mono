package proposer

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"net/url"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"

	pkgFlags "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/flags"
)

// Config contains all configurations to initialize a Taiko proposer.
type Config struct {
	*rpc.ClientConfig
	L1ProposerPrivKey          *ecdsa.PrivateKey
	L2SuggestedFeeRecipient    common.Address
	ExtraData                  string
	ProposeInterval            time.Duration
	LocalAddresses             []common.Address
	LocalAddressesOnly         bool
	MinGasUsed                 uint64
	MinTxListBytes             uint64
	MinProposingInternal       time.Duration
	MaxProposedTxListsPerEpoch uint64
	ProposeBlockTxGasLimit     uint64
	ProverEndpoints            []*url.URL
	OptimisticTierFee          *big.Int
	SgxTierFee                 *big.Int
	TierFeePriceBump           *big.Int
	MaxTierFeePriceBumps       uint64
	IncludeParentMetaHash      bool
	BlobAllowed                bool
	TxmgrConfigs               *txmgr.CLIConfig
	L1BlockBuilderTip          *big.Int
	PreconfirmationRPC         string
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

	var localAddresses []common.Address
	if c.IsSet(flags.TxPoolLocals.Name) {
		for _, account := range strings.Split(c.String(flags.TxPoolLocals.Name), ",") {
			if trimmed := strings.TrimSpace(account); !common.IsHexAddress(trimmed) {
				return nil, fmt.Errorf("invalid account in --txpool.locals: %s", trimmed)
			}
			localAddresses = append(localAddresses, common.HexToAddress(account))
		}
	}

	var proverEndpoints []*url.URL
	for _, e := range strings.Split(c.String(flags.ProverEndpoints.Name), ",") {
		endpoint, err := url.Parse(e)
		if err != nil {
			return nil, err
		}
		proverEndpoints = append(proverEndpoints, endpoint)
	}

	optimisticTierFee, err := utils.GWeiToWei(c.Float64(flags.OptimisticTierFee.Name))
	if err != nil {
		return nil, err
	}

	sgxTierFee, err := utils.GWeiToWei(c.Float64(flags.SgxTierFee.Name))
	if err != nil {
		return nil, err
	}

	l1RPCUrl := c.String(flags.L1WSEndpoint.Name)
	preconfirmationRPC := c.String(flags.PreconfirmationRPC.Name)
	if len(preconfirmationRPC) > 0 {
		l1RPCUrl = preconfirmationRPC
	}

	return &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        c.String(flags.L1WSEndpoint.Name),
			L2Endpoint:        c.String(flags.L2HTTPEndpoint.Name),
			TaikoL1Address:    common.HexToAddress(c.String(flags.TaikoL1Address.Name)),
			TaikoL2Address:    common.HexToAddress(c.String(flags.TaikoL2Address.Name)),
			L2EngineEndpoint:  c.String(flags.L2AuthEndpoint.Name),
			JwtSecret:         string(jwtSecret),
			TaikoTokenAddress: common.HexToAddress(c.String(flags.TaikoTokenAddress.Name)),
			Timeout:           c.Duration(flags.RPCTimeout.Name),
			ProverSetAddress:  common.HexToAddress(c.String(flags.ProverSetAddress.Name)),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(l2SuggestedFeeRecipient),
		ExtraData:                  c.String(flags.ExtraData.Name),
		ProposeInterval:            c.Duration(flags.ProposeInterval.Name),
		LocalAddresses:             localAddresses,
		LocalAddressesOnly:         c.Bool(flags.TxPoolLocalsOnly.Name),
		MinGasUsed:                 c.Uint64(flags.MinGasUsed.Name),
		MinTxListBytes:             c.Uint64(flags.MinTxListBytes.Name),
		MinProposingInternal:       c.Duration(flags.MinProposingInternal.Name),
		MaxProposedTxListsPerEpoch: c.Uint64(flags.MaxProposedTxListsPerEpoch.Name),
		ProposeBlockTxGasLimit:     c.Uint64(flags.TxGasLimit.Name),
		ProverEndpoints:            proverEndpoints,
		OptimisticTierFee:          optimisticTierFee,
		SgxTierFee:                 sgxTierFee,
		TierFeePriceBump:           new(big.Int).SetUint64(c.Uint64(flags.TierFeePriceBump.Name)),
		MaxTierFeePriceBumps:       c.Uint64(flags.MaxTierFeePriceBumps.Name),
		IncludeParentMetaHash:      c.Bool(flags.ProposeBlockIncludeParentMetaHash.Name),
		BlobAllowed:                c.Bool(flags.BlobAllowed.Name),
		L1BlockBuilderTip:          new(big.Int).SetUint64(c.Uint64(flags.L1BlockBuilderTip.Name)),
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			l1RPCUrl,
			l1ProposerPrivKey,
			c,
		),
	}, nil
}
