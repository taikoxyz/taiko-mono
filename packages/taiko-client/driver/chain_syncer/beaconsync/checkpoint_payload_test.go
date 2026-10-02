package beaconsync

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CheckpointPayloadTestSuite covers the conversion of a checkpoint head into the payload beacon sync imports
// it with. It needs no devnet.
type CheckpointPayloadTestSuite struct {
	suite.Suite
	originalUnzen uint64
	originalEtna  uint64
}

func (s *CheckpointPayloadTestSuite) SetupTest() {
	s.originalUnzen, s.originalEtna = gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, 100
}

func (s *CheckpointPayloadTestSuite) TearDownTest() {
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = s.originalUnzen, s.originalEtna
}

// checkpointBlock returns a checkpoint head with the given timestamp, zk gas difficulty and
// parentBeaconBlockRoot.
func checkpointBlock(time uint64, difficulty int64, root *common.Hash) *types.Block {
	return types.NewBlockWithHeader(&types.Header{
		Number:           big.NewInt(5),
		Time:             time,
		Difficulty:       big.NewInt(difficulty),
		ParentBeaconRoot: root,
		BaseFee:          big.NewInt(1),
		GasLimit:         30_000_000,
		Extra:            make([]byte, 7),
	})
}

func (s *CheckpointPayloadTestSuite) TestEmptyEtnaHeadKeepsZeroDifficultyAndReturnsRoot() {
	root := common.HexToHash("0xaa")

	payload, beaconRoot, err := checkpointPayload(params.TaikoInternalNetworkID, checkpointBlock(100, 0, &root))
	s.Require().NoError(err)
	s.Require().NotNil(payload.HeaderDifficulty)
	s.Equal(uint64(0), payload.HeaderDifficulty.Uint64())
	s.Require().NotNil(beaconRoot)
	s.Equal(root, *beaconRoot)
}

func (s *CheckpointPayloadTestSuite) TestPreEtnaUnzenHeadMatchesBlockValueConversion() {
	// A pre-Etna Unzen header carries a zero parentBeaconBlockRoot; it is imported with V2 all the same.
	block := checkpointBlock(50, 7, &common.Hash{})

	payload, beaconRoot, err := checkpointPayload(params.TaikoInternalNetworkID, block)
	s.Require().NoError(err)
	s.Nil(beaconRoot)
	s.Require().NotNil(payload.HeaderDifficulty)
	s.Equal(uint64(7), payload.HeaderDifficulty.Uint64())

	// Beacon sync used to normalize with the envelope's block value, which equals a non-zero difficulty.
	envelope := engine.BlockToExecutableData(block, nil, nil, nil)
	blockValuePayload, err := rpc.NormalizeExecutableData(
		params.TaikoInternalNetworkID,
		envelope.ExecutionPayload,
		envelope.BlockValue,
	)
	s.Require().NoError(err)
	s.Equal(blockValuePayload, payload)
}

func (s *CheckpointPayloadTestSuite) TestEtnaHeadWithoutRootFails() {
	payload, beaconRoot, err := checkpointPayload(params.TaikoInternalNetworkID, checkpointBlock(100, 0, nil))
	s.ErrorContains(err, "missing parentBeaconBlockRoot")
	s.Nil(payload)
	s.Nil(beaconRoot)
}

func TestCheckpointPayloadTestSuite(t *testing.T) {
	suite.Run(t, new(CheckpointPayloadTestSuite))
}
