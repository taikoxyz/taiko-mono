package txlistdecompressor

import (
	"crypto/rand"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

var (
	chainID    = new(big.Int).SetUint64(167001)
	testKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
	testAddr   = crypto.PubkeyToAddress(testKey.PublicKey)
)

type TxListDecompressorTestSuite struct {
	testutils.ClientTestSuite
	d *TxListDecompressor
}

func (s *TxListDecompressorTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	s.d = NewTxListDecompressor(
		params.MaxGasLimit,
		rpc.BlockMaxTxListBytes,
		chainID,
	)
}

func (s *TxListDecompressorTestSuite) TestZeroBytes() {
	s.Empty(s.d.TryDecompress(chainID, common.Big1, []byte{}, false))
}

func (s *TxListDecompressorTestSuite) TestCalldataSize() {
	s.Empty(s.d.TryDecompress(chainID, common.Big1, randBytes(rpc.BlockMaxTxListBytes+1), false))
	s.Empty(s.d.TryDecompress(chainID, common.Big1, randBytes(rpc.BlockMaxTxListBytes-1), false))
}

func (s *TxListDecompressorTestSuite) TestValidTxList() {
	compressed, err := utils.Compress(rlpEncodedTransactionBytes(1, true))
	s.Nil(err)
	decompressed, err := utils.Decompress(compressed)
	s.Nil(err)

	s.Equal(s.d.TryDecompress(chainID, common.Big1, compressed, true), decompressed)
	s.Equal(s.d.TryDecompress(chainID, common.Big1, compressed, false), decompressed)
}

func (s *TxListDecompressorTestSuite) TestInvalidTxList() {
	compressed, err := utils.Compress(randBytes(1024))
	s.Nil(err)

	s.Zero(len(s.d.TryDecompress(chainID, common.Big1, compressed, true)))
	s.Zero(len(s.d.TryDecompress(chainID, common.Big1, compressed, false)))
}

func (s *TxListDecompressorTestSuite) TestInvalidZlibBytes() {
	s.Zero(len(s.d.TryDecompress(chainID, common.Big1, randBytes(1024), true)))
	s.Zero(len(s.d.TryDecompress(chainID, common.Big1, randBytes(1024), false)))
}

func TestDriverTestSuite(t *testing.T) {
	suite.Run(t, new(TxListDecompressorTestSuite))
}

func rlpEncodedTransactionBytes(l int, signed bool) []byte {
	txs := make(types.Transactions, 0)
	for i := 0; i < l; i++ {
		var tx *types.Transaction
		if signed {
			txData := &types.LegacyTx{Nonce: 1, To: &testAddr, GasPrice: common.Big256, Value: common.Big1, Gas: 10}

			tx = types.MustSignNewTx(testKey, types.LatestSigner(&params.ChainConfig{ChainID: chainID}), txData)
		} else {
			tx = types.NewTransaction(1, testAddr, common.Big1, 10, new(big.Int).SetUint64(10*params.GWei), nil)
		}
		txs = append(txs, tx)
	}
	b, _ := rlp.EncodeToBytes(txs)
	return b
}

func randBytes(l uint64) []byte {
	b := make([]byte, l)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Failed to generate random bytes", "error", err)
	}
	return b
}
