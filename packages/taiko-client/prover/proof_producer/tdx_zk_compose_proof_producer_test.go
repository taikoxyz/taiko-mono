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

func TestTdxZkComposeProducer_ResolveDummyZKProofType(t *testing.T) {
	cases := []struct {
		name     string
		input    ProofType
		expected ProofType
	}{
		{"zk_any maps to risc0", ProofTypeZKAny, ProofTypeZKR0},
		{"risc0 stays risc0", ProofTypeZKR0, ProofTypeZKR0},
		{"sp1 stays sp1", ProofTypeZKSP1, ProofTypeZKSP1},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			producer := &TdxZkComposeProofProducer{ProofType: c.input}
			require.Equal(t, c.expected, producer.resolveDummyZKProofType())
		})
	}
}

func TestTdxZkComposeProducer_RequestProof_Dummy(t *testing.T) {
	var (
		producer = &TdxZkComposeProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			TdxProducer:        &TdxProofProducer{Dummy: true, DummyProofProducer: DummyProofProducer{}},
			ProofType:          ProofTypeZKAny,
			VerifierIDs: map[ProofType]uint8{
				ProofTypeZKR0:  5,
				ProofTypeZKSP1: 6,
			},
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
	require.Equal(t, blockID, res.BatchID)
	require.NotEmpty(t, res.Proof)
	// Dummy flow must resolve zk_any to a concrete ZK type so Aggregate can look up a VerifierID.
	require.Equal(t, ProofTypeZKR0, res.ProofType)
}

func TestTdxZkComposeProducer_Aggregate_EmptyItems(t *testing.T) {
	producer := &TdxZkComposeProofProducer{
		Dummy:              true,
		DummyProofProducer: DummyProofProducer{},
		TdxProducer:        &TdxProofProducer{Dummy: true, DummyProofProducer: DummyProofProducer{}},
	}
	_, err := producer.Aggregate(context.Background(), nil, time.Now())
	require.ErrorIs(t, err, ErrInvalidLength)
}

func TestTdxZkComposeProducer_Aggregate_UnknownProofType(t *testing.T) {
	var (
		producer = &TdxZkComposeProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			TdxProducer:        &TdxProofProducer{Dummy: true, DummyProofProducer: DummyProofProducer{}},
			ProofType:          ProofTypeZKR0,
			VerifierIDs: map[ProofType]uint8{
				ProofTypeZKR0:  5,
				ProofTypeZKSP1: 6,
			},
		}
		blockID = common.Big32
		items   = []*ProofResponse{{
			BatchID:   blockID,
			Meta:      metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
			ProofType: ProofTypeZKAny,
		}}
	)

	_, err := producer.Aggregate(context.Background(), items, time.Now())
	require.ErrorContains(t, err, "unknown ZK proof type from raiko")
}

func TestTdxZkComposeProducer_Aggregate_Dummy(t *testing.T) {
	var (
		tdxVerifier   = common.HexToAddress("0x1234567890123456789012345678901234567890")
		tdxVerifierID = uint8(7)
		producer      = &TdxZkComposeProofProducer{
			Dummy:              true,
			DummyProofProducer: DummyProofProducer{},
			TdxProducer: &TdxProofProducer{
				Dummy:              true,
				DummyProofProducer: DummyProofProducer{},
				Verifier:           tdxVerifier,
				VerifierID:         tdxVerifierID,
			},
			ProofType: ProofTypeZKR0,
			VerifierIDs: map[ProofType]uint8{
				ProofTypeZKR0:  5,
				ProofTypeZKSP1: 6,
			},
		}
		blockID = common.Big32
		items   = []*ProofResponse{{
			BatchID:   blockID,
			Meta:      metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: blockID}, 0),
			Opts:      &ProposalProofRequestOptions{},
			ProofType: ProofTypeZKR0,
		}}
	)

	res, err := producer.Aggregate(context.Background(), items, time.Now())
	require.Nil(t, err)
	require.Equal(t, uint8(5), res.VerifierID)
	require.Equal(t, tdxVerifier, res.TdxProofVerifier)
	require.Equal(t, tdxVerifierID, res.TdxVerifierID)
	require.NotEmpty(t, res.BatchProof)
	require.NotEmpty(t, res.TdxBatchProof)
}
