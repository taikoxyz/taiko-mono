package eventDecoder

import (
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	addressLength    = 20
	bytes32Length    = 32
	maxBondTypeValue = 2 // matches LibBonds.BondType.LIVENESS
)

var (
	// ErrInvalidBondType indicates the encoded bond type exceeded the supported bounds.
	ErrInvalidBondType = errors.New("shasta event decoder: invalid bond type")
)

// DecodeProposedEvent decodes a Proposed event payload exactly like CodecOptimized.decodeProposedEvent.
func DecodeProposedEvent(data []byte) (*shastaBindings.IInboxProposedEventPayload, error) {
	r := newReader(data)
	payload := new(shastaBindings.IInboxProposedEventPayload)

	// Proposal
	id, err := r.readUint48()
	if err != nil {
		return nil, err
	}
	payload.Proposal.Id = uintToBig(id)

	if payload.Proposal.Proposer, err = r.readAddress(); err != nil {
		return nil, err
	}
	if payload.Proposal.Timestamp, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.Proposal.EndOfSubmissionWindowTimestamp, err = r.readBigUint48(); err != nil {
		return nil, err
	}

	// Derivation
	if payload.Derivation.OriginBlockNumber, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.Derivation.OriginBlockHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.Derivation.BasefeeSharingPctg, err = r.readUint8(); err != nil {
		return nil, err
	}

	sourcesLen, err := r.readUint16()
	if err != nil {
		return nil, err
	}

	payload.Derivation.Sources = make([]shastaBindings.IInboxDerivationSource, sourcesLen)
	for i := range payload.Derivation.Sources {
		isForced, err := r.readBool()
		if err != nil {
			return nil, err
		}
		payload.Derivation.Sources[i].IsForcedInclusion = isForced

		blobHashesLen, err := r.readUint16()
		if err != nil {
			return nil, err
		}

		slice := shastaBindings.LibBlobsBlobSlice{
			BlobHashes: make([][bytes32Length]byte, blobHashesLen),
		}
		for j := range slice.BlobHashes {
			if slice.BlobHashes[j], err = r.readBytes32(); err != nil {
				return nil, err
			}
		}

		if slice.Offset, err = r.readBigUint24(); err != nil {
			return nil, err
		}
		if slice.Timestamp, err = r.readBigUint48(); err != nil {
			return nil, err
		}
		payload.Derivation.Sources[i].BlobSlice = slice
	}

	if payload.Proposal.CoreStateHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.Proposal.DerivationHash, err = r.readBytes32(); err != nil {
		return nil, err
	}

	// Core state
	if payload.CoreState.NextProposalId, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.CoreState.LastProposalBlockId, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.CoreState.LastFinalizedProposalId, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.CoreState.LastCheckpointTimestamp, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.CoreState.LastFinalizedTransitionHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.CoreState.BondInstructionsHash, err = r.readBytes32(); err != nil {
		return nil, err
	}

	// Bond instructions
	bondInstructionsLen, err := r.readUint16()
	if err != nil {
		return nil, err
	}
	if bondInstructionsLen > 0 {
		payload.BondInstructions = make([]shastaBindings.LibBondsBondInstruction, bondInstructionsLen)
		for i := range payload.BondInstructions {
			if payload.BondInstructions[i].ProposalId, err = r.readBigUint48(); err != nil {
				return nil, err
			}
			if payload.BondInstructions[i].BondType, err = r.readUint8(); err != nil {
				return nil, err
			}
			if payload.BondInstructions[i].Payer, err = r.readAddress(); err != nil {
				return nil, err
			}
			if payload.BondInstructions[i].Payee, err = r.readAddress(); err != nil {
				return nil, err
			}
		}
	}

	return payload, nil
}

// DecodeProvedEvent decodes a Proved event payload exactly like CodecOptimized.decodeProvedEvent.
func DecodeProvedEvent(data []byte) (*shastaBindings.IInboxProvedEventPayload, error) {
	r := newReader(data)
	payload := new(shastaBindings.IInboxProvedEventPayload)
	var err error

	if payload.ProposalId, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.Transition.ProposalHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.Transition.ParentTransitionHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.Transition.Checkpoint.BlockNumber, err = r.readBigUint48(); err != nil {
		return nil, err
	}
	if payload.Transition.Checkpoint.BlockHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.Transition.Checkpoint.StateRoot, err = r.readBytes32(); err != nil {
		return nil, err
	}

	if payload.TransitionRecord.Span, err = r.readUint8(); err != nil {
		return nil, err
	}
	if payload.TransitionRecord.TransitionHash, err = r.readBytes32(); err != nil {
		return nil, err
	}
	if payload.TransitionRecord.CheckpointHash, err = r.readBytes32(); err != nil {
		return nil, err
	}

	if payload.Metadata.DesignatedProver, err = r.readAddress(); err != nil {
		return nil, err
	}
	if payload.Metadata.ActualProver, err = r.readAddress(); err != nil {
		return nil, err
	}

	bondLen, err := r.readUint16()
	if err != nil {
		return nil, err
	}
	if bondLen > 0 {
		payload.TransitionRecord.BondInstructions = make([]shastaBindings.LibBondsBondInstruction, bondLen)
		for i := range payload.TransitionRecord.BondInstructions {
			if payload.TransitionRecord.BondInstructions[i].ProposalId, err = r.readBigUint48(); err != nil {
				return nil, err
			}
			var bondType uint8
			if bondType, err = r.readUint8(); err != nil {
				return nil, err
			}
			if bondType > maxBondTypeValue {
				return nil, ErrInvalidBondType
			}
			payload.TransitionRecord.BondInstructions[i].BondType = bondType
			if payload.TransitionRecord.BondInstructions[i].Payer, err = r.readAddress(); err != nil {
				return nil, err
			}
			if payload.TransitionRecord.BondInstructions[i].Payee, err = r.readAddress(); err != nil {
				return nil, err
			}
		}
	}

	return payload, nil
}

// reader is a helper that walks through the event payload byte slice.
type reader struct {
	data []byte
	off  int
}

// newReader returns a new reader positioned at the start of the byte slice.
func newReader(data []byte) *reader {
	return &reader{data: data}
}

// read returns the next n bytes and advances the cursor.
func (r *reader) read(n int) ([]byte, error) {
	if remaining := len(r.data) - r.off; remaining < n {
		return nil, fmt.Errorf(
			"shasta event decoder: insufficient data, need %d bytes at offset %d (have %d)",
			n,
			r.off,
			remaining,
		)
	}
	start := r.off
	r.off += n
	return r.data[start:r.off], nil
}

// readUint8 reads a single byte.
func (r *reader) readUint8() (uint8, error) {
	b, err := r.read(1)
	if err != nil {
		return 0, err
	}
	return b[0], nil
}

// readUint16 reads a big-endian uint16.
func (r *reader) readUint16() (uint16, error) {
	val, err := r.readUintN(2)
	return uint16(val), err
}

// readUint24 reads a big-endian 24-bit integer.
func (r *reader) readUint24() (uint32, error) {
	val, err := r.readUintN(3)
	return uint32(val), err
}

// readUint48 reads a big-endian 48-bit integer.
func (r *reader) readUint48() (uint64, error) {
	return r.readUintN(6)
}

// readUintN reads an unsigned big-endian integer with the given byte width (<= 8).
func (r *reader) readUintN(n int) (uint64, error) {
	if n > 8 {
		return 0, fmt.Errorf("shasta event decoder: unsupported uint size %d", n)
	}
	b, err := r.read(n)
	if err != nil {
		return 0, err
	}
	var value uint64
	for _, by := range b {
		value = (value << 8) | uint64(by)
	}
	return value, nil
}

// readBigUint48 reads a uint48 and wraps it into a *big.Int.
func (r *reader) readBigUint48() (*big.Int, error) {
	val, err := r.readUint48()
	if err != nil {
		return nil, err
	}
	return uintToBig(val), nil
}

// readBigUint24 reads a uint24 and wraps it into a *big.Int.
func (r *reader) readBigUint24() (*big.Int, error) {
	val, err := r.readUint24()
	if err != nil {
		return nil, err
	}
	return uintToBig(uint64(val)), nil
}

// readBytes32 reads a 32-byte chunk.
func (r *reader) readBytes32() ([bytes32Length]byte, error) {
	var out [bytes32Length]byte
	b, err := r.read(bytes32Length)
	if err != nil {
		return out, err
	}
	copy(out[:], b)
	return out, nil
}

// readAddress reads a 20-byte address value.
func (r *reader) readAddress() (common.Address, error) {
	b, err := r.read(addressLength)
	if err != nil {
		return common.Address{}, err
	}
	return common.BytesToAddress(b), nil
}

// readBool reads a boolean encoded as a single byte.
func (r *reader) readBool() (bool, error) {
	v, err := r.readUint8()
	if err != nil {
		return false, err
	}
	return v != 0, nil
}

// uintToBig converts the provided uint64 into a *big.Int.
func uintToBig(value uint64) *big.Int {
	return new(big.Int).SetUint64(value)
}
