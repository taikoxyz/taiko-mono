package blocksinserter

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EtnaHelpersTestSuite covers the fork-aware transactions-list and payload-fingerprint helpers, and the
// preconfirmation Etna guard. It needs no devnet.
type EtnaHelpersTestSuite struct {
	suite.Suite
}

func (s *EtnaHelpersTestSuite) signedTx(nonce uint64) *types.Transaction {
	key, err := crypto.GenerateKey()
	s.Nil(err)
	tx, err := types.SignTx(
		types.NewTransaction(nonce, common.Address{}, common.Big0, 21_000, big.NewInt(1), nil),
		types.LatestSignerForChainID(params.TaikoInternalNetworkID),
		key,
	)
	s.Nil(err)
	return tx
}

func (s *EtnaHelpersTestSuite) sampleMeta() *createExecutionPayloadsMetaData {
	return &createExecutionPayloadsMetaData{
		ParentHash:            common.HexToHash("0x01"),
		Timestamp:             100,
		SuggestedFeeRecipient: common.HexToAddress("0x02"),
		MixHash:               common.HexToHash("0x03"),
		ExtraData:             []byte{0, 0, 0, 0, 0, 0, 7},
	}
}

func (s *EtnaHelpersTestSuite) TestEncodeTxListWithoutAnchorIsEmptyList() {
	b, err := encodeTxList(nil, nil)
	s.Nil(err)
	s.Equal([]byte{0xc0}, b)

	b, err = encodeTxList(nil, types.Transactions{})
	s.Nil(err)
	s.Equal([]byte{0xc0}, b)
}

func (s *EtnaHelpersTestSuite) TestEncodeTxListPrependsAnchor() {
	anchorTx, userTx := s.signedTx(1), s.signedTx(2)

	b, err := encodeTxList(anchorTx, types.Transactions{userTx})
	s.Nil(err)

	var decoded types.Transactions
	s.Nil(rlp.DecodeBytes(b, &decoded))
	s.Equal(2, len(decoded))
	s.Equal(anchorTx.Hash(), decoded[0].Hash())
	s.Equal(userTx.Hash(), decoded[1].Hash())

	b, err = encodeTxList(nil, types.Transactions{userTx})
	s.Nil(err)
	// Decode into a fresh slice: rlp would reuse the old elements, which keep their cached hashes.
	decoded = nil
	s.Nil(rlp.DecodeBytes(b, &decoded))
	s.Equal(1, len(decoded))
	s.Equal(userTx.Hash(), decoded[0].Hash())
}

func (s *EtnaHelpersTestSuite) TestBuildPayloadArgsIDDelegatesToRPC() {
	meta := s.sampleMeta()
	txListHash := common.HexToHash("0x04")
	s.Equal(
		rpc.BuildPayloadArgsID(
			meta.ParentHash, meta.Timestamp, meta.SuggestedFeeRecipient, meta.MixHash, meta.ExtraData, txListHash, nil,
		),
		buildPayloadArgsID(meta, txListHash),
	)

	root := common.HexToHash("0xaa")
	meta.ParentBeaconBlockRoot = &root
	s.Equal(
		rpc.BuildPayloadArgsID(
			meta.ParentHash, meta.Timestamp, meta.SuggestedFeeRecipient, meta.MixHash, meta.ExtraData, txListHash, &root,
		),
		buildPayloadArgsID(meta, txListHash),
	)
}

func (s *EtnaHelpersTestSuite) TestInsertPreconfBlockFromEnvelopeRejectsEtna() {
	originalUnzen, originalEtna := gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	s.T().Cleanup(func() { gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = originalUnzen, originalEtna })
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, 100

	// The L2 client has no connection, so any RPC would panic: the Etna check must return first.
	cli := &rpc.Client{L2: &rpc.EthClient{ChainID: params.TaikoInternalNetworkID}}
	envelope := &preconf.Envelope{Payload: &eth.ExecutionPayload{Timestamp: eth.Uint64Quantity(100)}}

	header, err := InsertPreconfBlockFromEnvelope(context.Background(), cli, envelope)
	s.Nil(header)
	s.ErrorIs(err, preconf.ErrNotSupportedAfterEtna)
}

func TestEtnaHelpersTestSuite(t *testing.T) {
	suite.Run(t, new(EtnaHelpersTestSuite))
}
