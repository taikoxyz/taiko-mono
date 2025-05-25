package beaconsync

import (
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type BeaconSyncProgressTrackerTestSuite struct {
	testutils.ClientTestSuite
	t *SyncProgressTracker
}

func (s *BeaconSyncProgressTrackerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	s.t = NewSyncProgressTracker(s.RPCClient.L2, 30*time.Second)
}

func (s *BeaconSyncProgressTrackerTestSuite) TestSyncProgressed() {
	s.False(syncProgressed(nil, &ethereum.SyncProgress{}), nil)
	s.False(syncProgressed(&ethereum.SyncProgress{}, &ethereum.SyncProgress{}))

	// Block
	s.True(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 0}, &ethereum.SyncProgress{CurrentBlock: 1}))
	s.False(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 0}, &ethereum.SyncProgress{CurrentBlock: 0}))
	s.False(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 1}, &ethereum.SyncProgress{CurrentBlock: 1}))

	// Fast sync fields
	s.True(syncProgressed(&ethereum.SyncProgress{PulledStates: 0}, &ethereum.SyncProgress{PulledStates: 1}))

	// Snap sync fields
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedAccounts: 0}, &ethereum.SyncProgress{SyncedAccounts: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedAccountBytes: 0}, &ethereum.SyncProgress{SyncedAccountBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedBytecodes: 0}, &ethereum.SyncProgress{SyncedBytecodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedBytecodeBytes: 0}, &ethereum.SyncProgress{SyncedBytecodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedStorage: 0}, &ethereum.SyncProgress{SyncedStorage: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedStorageBytes: 0}, &ethereum.SyncProgress{SyncedStorageBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedTrienodes: 0}, &ethereum.SyncProgress{HealedTrienodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedTrienodeBytes: 0}, &ethereum.SyncProgress{HealedTrienodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedBytecodes: 0}, &ethereum.SyncProgress{HealedBytecodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedBytecodeBytes: 0}, &ethereum.SyncProgress{HealedBytecodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealingTrienodes: 0}, &ethereum.SyncProgress{HealingTrienodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealingBytecode: 0}, &ethereum.SyncProgress{HealingBytecode: 1}))
}

func (s *BeaconSyncProgressTrackerTestSuite) TestClearMeta() {
	s.t.triggered = true
	s.t.ClearMeta()
	s.False(s.t.triggered)
}

func (s *BeaconSyncProgressTrackerTestSuite) TestHeadChanged() {
	s.True(s.t.NeedReSync(common.Big256))
	s.t.triggered = true
	s.True(s.t.NeedReSync(common.Big256))
}

func (s *BeaconSyncProgressTrackerTestSuite) TestOutOfSync() {
	s.False(s.t.OutOfSync())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestTriggered() {
	s.False(s.t.Triggered())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestLastSyncedBlockID() {
	s.Nil(s.t.LastSyncedBlockID())
	s.t.lastSyncedBlockID = common.Big1
	s.Equal(common.Big1.Uint64(), s.t.LastSyncedBlockID().Uint64())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestLastSyncedVerifiedBlockHash() {
	s.Equal(
		common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000"),
		s.t.LastSyncedBlockHash(),
	)
	randomHash := testutils.RandomHash()
	s.t.lastSyncedBlockHash = randomHash
	s.Equal(randomHash, s.t.LastSyncedBlockHash())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestToExecutableData() {
	testHeader := &types.Header{
		ParentHash:  testutils.RandomHash(),
		UncleHash:   types.EmptyUncleHash,
		Coinbase:    common.BytesToAddress(testutils.RandomHash().Bytes()),
		Root:        testutils.RandomHash(),
		TxHash:      testutils.RandomHash(),
		ReceiptHash: testutils.RandomHash(),
		Bloom:       types.BytesToBloom(testutils.RandomHash().Bytes()),
		Difficulty:  new(big.Int).SetUint64(utils.RandUint64(nil)),
		Number:      new(big.Int).SetUint64(utils.RandUint64(nil)),
		GasLimit:    utils.RandUint64(nil),
		GasUsed:     utils.RandUint64(nil),
		Time:        uint64(time.Now().Unix()),
		Extra:       testutils.RandomHash().Bytes(),
		MixDigest:   testutils.RandomHash(),
		Nonce:       types.EncodeNonce(utils.RandUint64(nil)),
		BaseFee:     new(big.Int).SetUint64(utils.RandUint64(nil)),
	}

	data := toExecutableData(testHeader)
	s.Equal(testHeader.ParentHash, data.ParentHash)
	s.Equal(testHeader.Coinbase, data.FeeRecipient)
	s.Equal(testHeader.Root, data.StateRoot)
	s.Equal(testHeader.ReceiptHash, data.ReceiptsRoot)
	s.Equal(testHeader.Bloom.Bytes(), data.LogsBloom)
	s.Equal(testHeader.MixDigest, data.Random)
	s.Equal(testHeader.Number.Uint64(), data.Number)
	s.Equal(testHeader.GasLimit, data.GasLimit)
	s.Equal(testHeader.GasUsed, data.GasUsed)
	s.Equal(testHeader.Time, data.Timestamp)
	s.Equal(testHeader.Extra, data.ExtraData)
	s.Equal(testHeader.BaseFee, data.BaseFeePerGas)
	s.Equal(testHeader.Hash(), data.BlockHash)
	s.Equal(testHeader.TxHash, data.TxHash)
}

func TestBeaconSyncProgressTrackerTestSuite(t *testing.T) {
	suite.Run(t, new(BeaconSyncProgressTrackerTestSuite))
}
