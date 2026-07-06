package transaction

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func (s *TransactionTestSuite) TestBuildTxs() {
	header, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.NotNil(header)

	builder := s.builder.BuildProveBatchesShasta(context.Background(), &producer.BatchProofs{
		ProofResponses: []*producer.ProofResponse{{
			BatchID: common.Big1,
			Meta:    metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: common.Big1}, 0),
			Proof:   testutils.RandomBytes(100),
			Opts: &producer.ProposalProofRequestOptions{
				Headers: []*types.Header{header},
				L2BlockNums: []*big.Int{
					header.Number,
				},
				Checkpoint: &producer.Checkpoint{
					BlockNumber: header.Number,
					BlockHash:   header.Hash(),
					StateRoot:   header.Root,
				},
			},
			ProofType: producer.ProofTypeOp,
		}},
	})
	_, err = builder(&bind.TransactOpts{})
	s.Nil(err)
}
