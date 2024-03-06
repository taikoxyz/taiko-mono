package transaction

import (
	"context"
	"errors"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	testKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
	testAddr   = crypto.PubkeyToAddress(testKey.PublicKey)
)

type TransactionTestSuite struct {
	testutils.ClientTestSuite
	sender  *Sender
	builder *ProveBlockTxBuilder
}

func (s *TransactionTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)

	s.sender = NewSender(s.RPCClient, 5*time.Second, nil, 1*time.Minute)
	s.builder = NewProveBlockTxBuilder(s.RPCClient, l1ProverPrivKey, nil, common.Big256, common.Big2)
}

func (s *TransactionTestSuite) TestIsSubmitProofTxErrorRetryable() {
	s.True(isSubmitProofTxErrorRetryable(errors.New(testAddr.String()), common.Big0))
	s.False(isSubmitProofTxErrorRetryable(errors.New("L1_NOT_SPECIAL_PROVER"), common.Big0))
	s.False(isSubmitProofTxErrorRetryable(errors.New("L1_DUP_PROVERS"), common.Big0))
	s.False(isSubmitProofTxErrorRetryable(errors.New("L1_"+testAddr.String()), common.Big0))
}

func (s *TransactionTestSuite) TestSendTxWithBackoff() {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l1HeadChild, err := s.RPCClient.L1.HeaderByNumber(context.Background(), new(big.Int).Sub(l1Head.Number, common.Big1))
	s.Nil(err)
	meta := &bindings.TaikoDataBlockMetadata{L1Height: l1HeadChild.Number.Uint64(), L1Hash: l1HeadChild.Hash()}
	s.NotNil(s.sender.Send(
		context.Background(),
		&producer.ProofWithHeader{
			Meta:    meta,
			BlockID: common.Big1,
			Header:  &types.Header{},
			Opts:    &producer.ProofRequestOptions{EventL1Hash: l1Head.Hash()},
		},
		func(nonce *big.Int) (*types.Transaction, error) { return nil, errors.New("L1_TEST") },
	))

	s.Nil(s.sender.Send(
		context.Background(),
		&producer.ProofWithHeader{
			Meta:    meta,
			BlockID: common.Big1,
			Header:  &types.Header{},
			Opts:    &producer.ProofRequestOptions{EventL1Hash: l1Head.Hash()},
		},
		func(nonce *big.Int) (*types.Transaction, error) {
			height, err := s.RPCClient.L1.BlockNumber(context.Background())
			s.Nil(err)

			var block *types.Block
			for {
				block, err = s.RPCClient.L1.BlockByNumber(context.Background(), new(big.Int).SetUint64(height))
				s.Nil(err)
				if block.Transactions().Len() != 0 {
					break
				}
				height--
			}

			return block.Transactions()[0], nil
		},
	))
}

func TestTxSenderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionTestSuite))
}
