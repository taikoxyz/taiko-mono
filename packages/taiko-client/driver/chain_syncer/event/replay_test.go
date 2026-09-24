package event

import (
	"context"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/holiman/uint256"
	"github.com/labstack/echo/v4"
	dto "github.com/prometheus/client_model/go"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	blocksInserter "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/blocks_inserter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/derivation"
	preconfblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

func (s *EventSyncerTestSuite) TestReplayWithOmittedTransactionReportsExecutionHead() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	meta := s.ProposeAndInsertValidBlock(s.p, s.s)
	block, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Require().NoError(err)
	parent, err := s.RPCClient.L2.BlockByHash(ctx, block.ParentHash())
	s.Require().NoError(err)
	_, anchorNumber, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(block.Transactions()[0])
	s.Require().NoError(err)
	constructor, err := anchorTxConstructor.New(s.RPCClient)
	s.Require().NoError(err)
	notifications := make(chan *encoding.LastSeenProposal, 1)
	inserter := blocksInserter.NewBlocksInserter(s.RPCClient, s.s.progressTracker, constructor, notifications)
	server, err := preconfblocks.New(
		"*", nil, common.Address{}, common.HexToAddress(os.Getenv("TAIKO_ANCHOR")), inserter, s.RPCClient, nil,
	)
	s.Require().NoError(err)
	source := &derivation.DerivationSourcePayload{
		ParentBlock: parent,
		BlockPayloads: []*derivation.BlockPayload{{BlockManifest: manifest.BlockManifest{
			Timestamp:         block.Time(),
			Coinbase:          block.Coinbase(),
			AnchorBlockNumber: anchorNumber,
			GasLimit:          block.GasLimit() - consensus.AnchorV3V4GasLimit,
			Transactions:      append(types.Transactions{}, block.Transactions()[1:]...),
		}}},
	}

	// A nonce gap makes this extra input transaction ineligible for execution.
	// Building with it must still yield the original block, but a different payload ID.
	nonce, err := s.RPCClient.L2.NonceAt(ctx, s.TestAddr, block.Number())
	s.Require().NoError(err)
	omitted, err := types.SignTx(types.NewTransaction(
		nonce+100, common.Address{1}, common.Big0, 21_000, big.NewInt(10_000_000_000), nil,
	), types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Require().NoError(err)
	source.BlockPayloads[0].Transactions = append(source.BlockPayloads[0].Transactions, omitted)
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	s.receiveReplayNotification(ctx, notifications)
	originalOrigin, err := s.RPCClient.L2.L1OriginByID(ctx, block.Number())
	s.Require().NoError(err)
	afterOriginal, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.Require().Equal(block.Hash(), afterOriginal.Hash())

	// Reproduce the incident's retained unsafe suffix: the proposal ends below
	// the execution head, and these descendants have not been proposed on L1.
	unsafeHead := s.appendReplayPreconfirmation(ctx, inserter, constructor, block.Header(), anchorNumber)
	unsafeHead = s.appendReplayPreconfirmation(ctx, inserter, constructor, unsafeHead, anchorNumber)
	s.Require().Greater(unsafeHead.Number.Uint64(), block.NumberU64())
	s.checkReplayStatus(server, unsafeHead.Number.Uint64())

	// Recovery uses only the transactions that made it into the block.
	source.BlockPayloads[0].Transactions = block.Transactions()[1:]
	// Force notification coalescing and verify that the completed rebuild is
	// counted even though an older completion has to be discarded.
	notifications <- &encoding.LastSeenProposal{TaikoProposalMetaData: meta}
	var countBefore, countAfter dto.Metric
	s.Require().NoError(metrics.DriverReorgsByProposalCounter.Write(&countBefore))
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	completion := s.receiveReplayNotification(ctx, notifications)
	s.Require().NoError(metrics.DriverReorgsByProposalCounter.Write(&countAfter))
	s.Equal(countBefore.GetCounter().GetValue()+1, countAfter.GetCounter().GetValue())
	recoveredOrigin, err := s.RPCClient.L2.L1OriginByID(ctx, block.Number())
	s.Require().NoError(err)
	s.NotEqual(originalOrigin.BuildPayloadArgsID, recoveredOrigin.BuildPayloadArgsID)
	s.Equal(block.NumberU64(), completion.LastBlockID)
	afterReplay, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.Equal(block.Hash(), afterReplay.Hash())
	replayedHead, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Require().NoError(err)
	// Engines may retain or truncate the unsafe suffix. Status must reflect
	// the resulting head in either case.
	s.checkReplayStatus(server, replayedHead.Number.Uint64())
	confirmedOrigin, err := s.RPCClient.L2.HeadL1Origin(ctx)
	s.Require().NoError(err)
	s.Equal(block.Number(), confirmedOrigin.BlockID)

	// An already-known proposal updates origins without counting another rebuild.
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	s.receiveReplayNotification(ctx, notifications)
	var countKnown dto.Metric
	s.Require().NoError(metrics.DriverReorgsByProposalCounter.Write(&countKnown))
	s.Equal(countAfter.GetCounter().GetValue(), countKnown.GetCounter().GetValue())

	// Changing a header field really replaces the canonical block at this height.
	source.BlockPayloads[0].Coinbase = common.Address{2}
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	s.Equal(block.NumberU64(), s.receiveReplayNotification(ctx, notifications).LastBlockID)
	replacement, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.NotEqual(block.Hash(), replacement.Hash())
	newHead, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Require().NoError(err)
	s.Equal(replacement.Hash(), newHead.Hash(), "a real replacement must discard the old unsafe suffix")
	s.checkReplayStatus(server, newHead.Number.Uint64())
}

func (s *EventSyncerTestSuite) checkReplayStatus(server *preconfblocks.PreconfBlockAPIServer, expected uint64) {
	s.T().Helper()
	recorder := httptest.NewRecorder()
	ctx := echo.New().NewContext(httptest.NewRequest(http.MethodGet, "/status", nil), recorder)
	s.Require().NoError(server.GetStatus(ctx))
	var status preconfblocks.Status
	s.Require().NoError(json.Unmarshal(recorder.Body.Bytes(), &status))
	s.Equal(expected, status.HighestUnsafeL2PayloadBlockID)
}

func (s *EventSyncerTestSuite) appendReplayPreconfirmation(
	ctx context.Context,
	inserter *blocksInserter.Shasta,
	constructor *anchorTxConstructor.AnchorTxConstructor,
	parent *types.Header,
	anchorNumber uint64,
) *types.Header {
	s.T().Helper()
	anchor, err := s.RPCClient.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(anchorNumber))
	s.Require().NoError(err)
	baseFee, err := s.RPCClient.CalculateBaseFee(ctx, parent)
	s.Require().NoError(err)
	number := new(big.Int).Add(parent.Number, common.Big1)
	anchorTx, err := constructor.AssembleAnchorV4Tx(
		ctx, parent, anchor.Number, anchor.Hash(), anchor.Root, common.Big0, number, baseFee,
	)
	s.Require().NoError(err)
	txs, err := rlp.EncodeToBytes(types.Transactions{anchorTx})
	s.Require().NoError(err)
	compressed, err := utils.Compress(txs)
	s.Require().NoError(err)
	mixHash, err := encoding.CalculateShastaMixHash(parent.Difficulty, number)
	s.Require().NoError(err)
	u256BaseFee, overflow := uint256.FromBig(baseFee)
	s.Require().False(overflow)
	headers, err := inserter.InsertPreconfBlocksFromEnvelopes(ctx, []*preconf.Envelope{{
		Payload: &eth.ExecutionPayload{
			ParentHash: parent.Hash(), FeeRecipient: parent.Coinbase, PrevRandao: eth.Bytes32(mixHash[:]),
			BlockNumber: eth.Uint64Quantity(number.Uint64()), GasLimit: eth.Uint64Quantity(parent.GasLimit),
			Timestamp: eth.Uint64Quantity(parent.Time + 1), ExtraData: eth.BytesMax32(parent.Extra),
			BaseFeePerGas: eth.Uint256Quantity(*u256BaseFee), Transactions: []eth.Data{compressed},
		},
	}}, false)
	s.Require().NoError(err)
	s.Require().Len(headers, 1)
	return headers[0]
}

func (s *EventSyncerTestSuite) receiveReplayNotification(
	ctx context.Context,
	notifications <-chan *encoding.LastSeenProposal,
) *encoding.LastSeenProposal {
	s.T().Helper()
	select {
	case proposal := <-notifications:
		return proposal
	case <-ctx.Done():
		s.T().Fatal("timed out waiting for proposal completion")
		return nil
	}
}
