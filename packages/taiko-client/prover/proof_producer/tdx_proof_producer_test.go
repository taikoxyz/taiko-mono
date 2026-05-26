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

func TestTdxProofProducer_RequestProof_Dummy(t *testing.T) {
	var (
		producer = &TdxProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
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

func TestTdxProofProducer_Aggregate_EmptyItems(t *testing.T) {
	producer := &TdxProofProducer{Dummy: true, DummyProofProducer: DummyProofProducer{}}
	_, err := producer.Aggregate(context.Background(), nil, time.Now())
	require.ErrorIs(t, err, ErrInvalidLength)
}

func TestTdxProofProducer_Aggregate_DummyReturnsVerifier(t *testing.T) {
	var (
		verifier   = common.HexToAddress("0x1234567890123456789012345678901234567890")
		verifierID = uint8(7)
		producer   = &TdxProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			Verifier:           verifier,
			VerifierID:         verifierID,
		}
		blockID = common.Big32
		items   = []*ProofResponse{{
			BatchID:   blockID,
			Meta:      metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
			ProofType: ProofTypeTdx,
		}}
	)

	res, err := producer.Aggregate(context.Background(), items, time.Now())
	require.Nil(t, err)
	require.Equal(t, verifier, res.Verifier)
	require.Equal(t, verifierID, res.VerifierID)
	require.NotEmpty(t, res.BatchProof)
}
