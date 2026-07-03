package producer

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestComposeProducerRequestProof(t *testing.T) {
	var (
		producer = &ComposeProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			SgxGethProducer:    &SgxGethProofProducer{Dummy: true},
		}
		blockID = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProposalProofRequestOptions{},
		blockID,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BatchID, blockID)
	require.NotEmpty(t, res.Proof)
}

func TestComposeProducerAggregateUsesItemProofType(t *testing.T) {
	producer := &ComposeProofProducer{
		VerifierIDs: map[ProofType]uint8{
			ProofTypeZKSP1: 6,
		},
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
		SgxGethProducer:    &SgxGethProofProducer{Dummy: true},
		ProofType:          ProofTypeZKR0,
	}

	result, err := producer.Aggregate(
		context.Background(),
		[]*ProofResponse{
			{
				BatchID:   common.Big1,
				ProofType: ProofTypeZKSP1,
				Meta: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: common.Big1},
					0,
				),
				Opts: &ProposalProofRequestOptions{},
			},
		},
		time.Now(),
	)

	require.NoError(t, err)
	require.Equal(t, ProofTypeZKSP1, result.ProofType)
}
