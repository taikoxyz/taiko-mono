package blocksinserter

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/trie"
)

func testTxList(t *testing.T) types.Transactions {
	t.Helper()

	to := common.HexToAddress("0x000cb000E880A92a8f383D69dA2142a969B93DE7")
	txs := make(types.Transactions, 0, 3)
	for i := uint64(0); i < 3; i++ {
		txs = append(txs, types.NewTx(&types.LegacyTx{
			Nonce:    i,
			To:       &to,
			Value:    big.NewInt(1),
			Gas:      21_000,
			GasPrice: big.NewInt(10_000_000),
			Data:     []byte{byte(i)},
		}))
	}
	return txs
}

func testBlockWithTxs(t *testing.T, txs types.Transactions) *types.Block {
	t.Helper()

	return types.NewBlock(
		&types.Header{Number: big.NewInt(9_973_923)},
		&types.Body{Transactions: txs},
		nil,
		trie.NewStackTrie(nil),
	)
}

func TestTxListMatchesBlockAfterEncodeDecodeRoundTrip(t *testing.T) {
	txs := testTxList(t)
	block := testBlockWithTxs(t, txs)

	// Simulate a re-derivation: the tx list is re-encoded and decoded again, so the
	// candidate transaction objects are not the same instances (and any byte-level
	// serialization context is lost), but the content is identical.
	encoded, err := rlp.EncodeToBytes(txs)
	if err != nil {
		t.Fatalf("EncodeToBytes() error = %v", err)
	}
	var decoded types.Transactions
	if err := rlp.DecodeBytes(encoded, &decoded); err != nil {
		t.Fatalf("DecodeBytes() error = %v", err)
	}

	if !txListMatchesBlock(block, decoded) {
		t.Fatalf("expected identical tx content to match the block after an encode/decode round trip")
	}
}

func TestTxListMatchesBlockRejectsDifferentTx(t *testing.T) {
	txs := testTxList(t)
	block := testBlockWithTxs(t, txs)

	altered := make(types.Transactions, len(txs))
	copy(altered, txs)
	to := common.HexToAddress("0x5F62d006C10C009ff50C878Cd6157aC861C99990")
	altered[1] = types.NewTx(&types.LegacyTx{
		Nonce:    1,
		To:       &to,
		Value:    big.NewInt(2),
		Gas:      21_000,
		GasPrice: big.NewInt(10_000_000),
	})

	if txListMatchesBlock(block, altered) {
		t.Fatalf("expected a tx list with a different transaction to not match the block")
	}
}

func TestTxListMatchesBlockRejectsMissingTx(t *testing.T) {
	txs := testTxList(t)
	block := testBlockWithTxs(t, txs)

	if txListMatchesBlock(block, txs[:len(txs)-1]) {
		t.Fatalf("expected a truncated tx list to not match the block")
	}
}

// TestKnownBlockContentAcceptsMatchingPayloadIDWhenSealerDroppedTxs pins the
// derivation-inserted case: the sealer dropped transactions from the manifest list while
// sealing, so the block's transactions root cannot match the pre-sealing list, but the
// recorded BuildPayloadArgs ID (computed from the same pre-sealing list at insertion time)
// equals the recomputed one and must be accepted.
func TestKnownBlockContentAcceptsMatchingPayloadIDWhenSealerDroppedTxs(t *testing.T) {
	manifestTxs := testTxList(t)
	sealedBlock := testBlockWithTxs(t, manifestTxs[:len(manifestTxs)-1])

	id := engine.PayloadID{0x02, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07}
	if !knownBlockContent(sealedBlock, manifestTxs, [8]byte(id), id) {
		t.Fatalf("expected a matching recorded payload ID to prove the block known despite dropped txs")
	}
}

func TestKnownBlockContentRejectsZeroStoredIDWhenTxRootDiffers(t *testing.T) {
	manifestTxs := testTxList(t)
	sealedBlock := testBlockWithTxs(t, manifestTxs[:len(manifestTxs)-1])

	if knownBlockContent(sealedBlock, manifestTxs, [8]byte{}, engine.PayloadID{0x02, 0x01}) {
		t.Fatalf("expected a zero recorded payload ID to not prove anything when the tx root differs")
	}
}

func TestKnownBlockContentRejectsMismatchedPayloadIDWhenTxRootDiffers(t *testing.T) {
	manifestTxs := testTxList(t)
	sealedBlock := testBlockWithTxs(t, manifestTxs[:len(manifestTxs)-1])

	stored := [8]byte{0x02, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00}
	if knownBlockContent(sealedBlock, manifestTxs, stored, engine.PayloadID{0x02, 0x01}) {
		t.Fatalf("expected a mismatched recorded payload ID to not prove the block known")
	}
}

func TestKnownBlockContentAcceptsExactTxListRegardlessOfPayloadID(t *testing.T) {
	txs := testTxList(t)
	block := testBlockWithTxs(t, txs)

	if !knownBlockContent(block, txs, [8]byte{}, engine.PayloadID{0x02, 0x01}) {
		t.Fatalf("expected an exact transactions root match to prove the block known on its own")
	}
}
