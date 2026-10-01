package derivation

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EtnaGasLimitTestSuite covers the fork-aware parent gas limit used by derivation. It needs no devnet.
type EtnaGasLimitTestSuite struct {
	suite.Suite
	originalUnzen uint64
	originalEtna  uint64
}

func (s *EtnaGasLimitTestSuite) SetupTest() {
	s.originalUnzen, s.originalEtna = gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, 1_000
}

func (s *EtnaGasLimitTestSuite) TearDownTest() {
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = s.originalUnzen, s.originalEtna
}

// inheritedGasLimit returns the gas limit ApplyInheritedMetadata assigns to a block whose parent has a
// 30M header gas limit and the given timestamp.
func (s *EtnaGasLimitTestSuite) inheritedGasLimit(parentTime uint64) uint64 {
	parent := types.NewBlockWithHeader(&types.Header{Number: big.NewInt(5), GasLimit: 30_000_000, Time: parentTime})
	sourcePayload := &DerivationSourcePayload{
		ParentBlock:   parent,
		BlockPayloads: []*BlockPayload{{BlockManifest: manifest.BlockManifest{Transactions: types.Transactions{}}}},
	}
	ApplyInheritedMetadata(
		sourcePayload,
		&shastaBindings.ShastaInboxClientProposed{Proposer: common.Address{}},
		parentTime+10,
		7,
		params.TaikoInternalNetworkID,
	)
	return sourcePayload.BlockPayloads[0].GasLimit
}

func (s *EtnaGasLimitTestSuite) TestApplyInheritedMetadataSubtractsReserveOnlyBeforeEtna() {
	s.Equal(uint64(29_000_000), s.inheritedGasLimit(999))
	s.Equal(uint64(30_000_000), s.inheritedGasLimit(1_000))
}

func (s *EtnaGasLimitTestSuite) TestValidateGasLimitUsesParentManifestGasLimit() {
	sourcePayload := &DerivationSourcePayload{
		BlockPayloads: []*BlockPayload{{BlockManifest: manifest.BlockManifest{GasLimit: 30_000_000}}},
	}
	etnaParent := &types.Header{Number: big.NewInt(5), GasLimit: 30_000_000, Time: 1_000}
	preEtnaParent := &types.Header{Number: big.NewInt(5), GasLimit: 30_000_000, Time: 999}

	// An Etna parent with a 30M header limit has a 30M manifest limit, so an unchanged 30M child is valid,
	s.True(validateGasLimit(sourcePayload, rpc.ManifestGasLimit(params.TaikoInternalNetworkID, etnaParent)))
	// while the same header limit before Etna leaves only 29M, outside the ±0.02% bound.
	s.False(validateGasLimit(sourcePayload, rpc.ManifestGasLimit(params.TaikoInternalNetworkID, preEtnaParent)))
}

func TestEtnaGasLimitTestSuite(t *testing.T) {
	suite.Run(t, new(EtnaGasLimitTestSuite))
}
