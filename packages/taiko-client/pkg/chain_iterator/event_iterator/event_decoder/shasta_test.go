package eventDecoder

import (
	"bytes"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

type decoderTestSuite struct {
	suite.Suite
}

func (s *decoderTestSuite) TestDecodeProposedEventRoundTrip() {
	payload := &shastaBindings.IInboxProposedEventPayload{
		Proposal: shastaBindings.IInboxProposal{
			Id:                             big.NewInt(1),
			Timestamp:                      big.NewInt(2),
			EndOfSubmissionWindowTimestamp: big.NewInt(3),
			Proposer:                       common.HexToAddress("0x1000000000000000000000000000000000000001"),
			CoreStateHash:                  common.HexToHash("0x01"),
			DerivationHash:                 common.HexToHash("0x02"),
		},
		Derivation: shastaBindings.IInboxDerivation{
			OriginBlockNumber:  big.NewInt(4),
			OriginBlockHash:    common.HexToHash("0xa1"),
			BasefeeSharingPctg: 5,
			Sources: []shastaBindings.IInboxDerivationSource{
				{
					IsForcedInclusion: true,
					BlobSlice: shastaBindings.LibBlobsBlobSlice{
						BlobHashes: [][32]byte{
							common.HexToHash("0xaa"),
							common.HexToHash("0xbb"),
						},
						Offset:    big.NewInt(6),
						Timestamp: big.NewInt(7),
					},
				},
			},
		},
		CoreState: shastaBindings.IInboxCoreState{
			NextProposalId:              big.NewInt(8),
			LastProposalBlockId:         big.NewInt(9),
			LastFinalizedProposalId:     big.NewInt(10),
			LastCheckpointTimestamp:     big.NewInt(11),
			LastFinalizedTransitionHash: common.HexToHash("0xcc"),
			BondInstructionsHash:        common.HexToHash("0xdd"),
		},
		BondInstructions: []shastaBindings.LibBondsBondInstruction{
			{
				ProposalId: big.NewInt(12),
				BondType:   1,
				Payer:      common.HexToAddress("0x2000000000000000000000000000000000000002"),
				Payee:      common.HexToAddress("0x3000000000000000000000000000000000000003"),
			},
			{
				ProposalId: big.NewInt(13),
				BondType:   2,
				Payer:      common.HexToAddress("0x4000000000000000000000000000000000000004"),
				Payee:      common.HexToAddress("0x5000000000000000000000000000000000000005"),
			},
		},
	}

	encoded := s.encodeProposedPayload(payload)
	decoded, err := DecodeProposedEvent(encoded)
	s.Require().NoError(err)
	s.Require().Equal(payload, decoded)
}

func (s *decoderTestSuite) TestDecodeProvedEventRoundTrip() {
	payload := &shastaBindings.IInboxProvedEventPayload{
		ProposalId: big.NewInt(21),
		Transition: shastaBindings.IInboxTransition{
			ProposalHash:         common.HexToHash("0x11"),
			ParentTransitionHash: common.HexToHash("0x22"),
			Checkpoint: shastaBindings.ICheckpointStoreCheckpoint{
				BlockNumber: big.NewInt(22),
				BlockHash:   common.HexToHash("0x33"),
				StateRoot:   common.HexToHash("0x44"),
			},
		},
		TransitionRecord: shastaBindings.IInboxTransitionRecord{
			Span:           9,
			TransitionHash: common.HexToHash("0x55"),
			CheckpointHash: common.HexToHash("0x66"),
			BondInstructions: []shastaBindings.LibBondsBondInstruction{
				{
					ProposalId: big.NewInt(31),
					BondType:   1,
					Payer:      common.HexToAddress("0x6000000000000000000000000000000000000006"),
					Payee:      common.HexToAddress("0x7000000000000000000000000000000000000007"),
				},
			},
		},
		Metadata: shastaBindings.IInboxTransitionMetadata{
			DesignatedProver: common.HexToAddress("0x8000000000000000000000000000000000000008"),
			ActualProver:     common.HexToAddress("0x9000000000000000000000000000000000000009"),
		},
	}

	encoded := s.encodeProvedPayload(payload)
	decoded, err := DecodeProvedEvent(encoded)
	s.Require().NoError(err)
	s.Require().Equal(payload, decoded)
}

func (s *decoderTestSuite) TestDecodeProvedEventInvalidBondType() {
	payload := &shastaBindings.IInboxProvedEventPayload{
		ProposalId: big.NewInt(1),
		Transition: shastaBindings.IInboxTransition{
			ProposalHash:         common.HexToHash("0xaa"),
			ParentTransitionHash: common.HexToHash("0xbb"),
			Checkpoint: shastaBindings.ICheckpointStoreCheckpoint{
				BlockNumber: big.NewInt(1),
				BlockHash:   common.HexToHash("0xcc"),
				StateRoot:   common.HexToHash("0xdd"),
			},
		},
		TransitionRecord: shastaBindings.IInboxTransitionRecord{
			Span:           1,
			TransitionHash: common.HexToHash("0xee"),
			CheckpointHash: common.HexToHash("0xff"),
			BondInstructions: []shastaBindings.LibBondsBondInstruction{
				{
					ProposalId: big.NewInt(2),
					BondType:   3, // invalid > LIVENESS
					Payer:      common.HexToAddress("0xabc0000000000000000000000000000000000abc"),
					Payee:      common.HexToAddress("0xdef0000000000000000000000000000000000def"),
				},
			},
		},
		Metadata: shastaBindings.IInboxTransitionMetadata{
			DesignatedProver: common.HexToAddress("0x1230000000000000000000000000000000000123"),
			ActualProver:     common.HexToAddress("0x4560000000000000000000000000000000000456"),
		},
	}

	encoded := s.encodeProvedPayload(payload)
	_, err := DecodeProvedEvent(encoded)
	s.Require().ErrorIs(err, ErrInvalidBondType)
}

func TestDecoderTestSuite(t *testing.T) {
	suite.Run(t, new(decoderTestSuite))
}

func (s *decoderTestSuite) encodeProposedPayload(payload *shastaBindings.IInboxProposedEventPayload) []byte {
	e := newEncoder()

	e.writeUint48(uintFromBig(payload.Proposal.Id))
	e.writeAddress(payload.Proposal.Proposer)
	e.writeUint48(uintFromBig(payload.Proposal.Timestamp))
	e.writeUint48(uintFromBig(payload.Proposal.EndOfSubmissionWindowTimestamp))

	e.writeUint48(uintFromBig(payload.Derivation.OriginBlockNumber))
	e.writeBytes32(payload.Derivation.OriginBlockHash)
	e.writeUint8(payload.Derivation.BasefeeSharingPctg)

	e.writeUint16(uint16(len(payload.Derivation.Sources)))
	for _, source := range payload.Derivation.Sources {
		e.writeBool(source.IsForcedInclusion)
		e.writeUint16(uint16(len(source.BlobSlice.BlobHashes)))
		for _, hash := range source.BlobSlice.BlobHashes {
			e.writeBytes32(hash)
		}
		e.writeUint24(uint32(uintFromBig(source.BlobSlice.Offset)))
		e.writeUint48(uintFromBig(source.BlobSlice.Timestamp))
	}

	e.writeBytes32(payload.Proposal.CoreStateHash)
	e.writeBytes32(payload.Proposal.DerivationHash)

	e.writeUint48(uintFromBig(payload.CoreState.NextProposalId))
	e.writeUint48(uintFromBig(payload.CoreState.LastProposalBlockId))
	e.writeUint48(uintFromBig(payload.CoreState.LastFinalizedProposalId))
	e.writeUint48(uintFromBig(payload.CoreState.LastCheckpointTimestamp))
	e.writeBytes32(payload.CoreState.LastFinalizedTransitionHash)
	e.writeBytes32(payload.CoreState.BondInstructionsHash)

	e.writeUint16(uint16(len(payload.BondInstructions)))
	for _, instruction := range payload.BondInstructions {
		e.writeUint48(uintFromBig(instruction.ProposalId))
		e.writeUint8(instruction.BondType)
		e.writeAddress(instruction.Payer)
		e.writeAddress(instruction.Payee)
	}

	return e.bytes()
}

func (s *decoderTestSuite) encodeProvedPayload(payload *shastaBindings.IInboxProvedEventPayload) []byte {
	e := newEncoder()

	e.writeUint48(uintFromBig(payload.ProposalId))
	e.writeBytes32(payload.Transition.ProposalHash)
	e.writeBytes32(payload.Transition.ParentTransitionHash)
	e.writeUint48(uintFromBig(payload.Transition.Checkpoint.BlockNumber))
	e.writeBytes32(payload.Transition.Checkpoint.BlockHash)
	e.writeBytes32(payload.Transition.Checkpoint.StateRoot)

	e.writeUint8(payload.TransitionRecord.Span)
	e.writeBytes32(payload.TransitionRecord.TransitionHash)
	e.writeBytes32(payload.TransitionRecord.CheckpointHash)

	e.writeAddress(payload.Metadata.DesignatedProver)
	e.writeAddress(payload.Metadata.ActualProver)

	e.writeUint16(uint16(len(payload.TransitionRecord.BondInstructions)))
	for _, instruction := range payload.TransitionRecord.BondInstructions {
		e.writeUint48(uintFromBig(instruction.ProposalId))
		e.writeUint8(instruction.BondType)
		e.writeAddress(instruction.Payer)
		e.writeAddress(instruction.Payee)
	}

	return e.bytes()
}

type encoder struct {
	buf bytes.Buffer
}

func newEncoder() *encoder {
	return &encoder{}
}

func (e *encoder) bytes() []byte {
	return e.buf.Bytes()
}

func (e *encoder) writeUint8(v uint8) {
	e.buf.WriteByte(v)
}

func (e *encoder) writeUint16(v uint16) {
	e.writeUintN(uint64(v), 2)
}

func (e *encoder) writeUint24(v uint32) {
	e.writeUintN(uint64(v), 3)
}

func (e *encoder) writeUint48(v uint64) {
	e.writeUintN(v, 6)
}

func (e *encoder) writeUintN(value uint64, n int) {
	tmp := make([]byte, n)
	for i := n - 1; i >= 0; i-- {
		tmp[i] = byte(value & 0xff)
		value >>= 8
	}
	e.buf.Write(tmp)
}

func (e *encoder) writeBytes32(b [32]byte) {
	e.buf.Write(b[:])
}

func (e *encoder) writeAddress(addr common.Address) {
	e.buf.Write(addr.Bytes())
}

func (e *encoder) writeBool(v bool) {
	if v {
		e.writeUint8(1)
	} else {
		e.writeUint8(0)
	}
}

func uintFromBig(b *big.Int) uint64 {
	if b == nil {
		return 0
	}
	return b.Uint64()
}
