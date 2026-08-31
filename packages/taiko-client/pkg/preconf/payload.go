package preconf

import (
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
)

// Envelope is the decoded, validated form of a preconfirmation gossip message
// used inside the driver. It is decoupled from `eth.ExecutionPayloadEnvelope`
// so ingest code can carry only the fields the driver consumes.
type Envelope struct {
	// Payload is the execution payload carried by the preconfirmation message.
	Payload *eth.ExecutionPayload
	// IsForcedInclusion signals that the block was sequenced via the
	// forced-inclusion path rather than the regular preconfirmation flow.
	IsForcedInclusion bool
	// Signature is the 65-byte secp256k1 signature covering the gossip
	// envelope bytes; nil when the envelope is synthesized locally (not
	// gossiped) or when the message is loaded from cache without signature
	// preservation.
	Signature *[65]byte
	// HeaderDifficulty is the Unzen-era `header.Difficulty` (= block zk gas
	// used) carried on the wire so receivers can reconstruct the sender's
	// block hash. Nil on Shasta-era messages, where `header.Difficulty` is
	// always zero. Copied straight off the decoded gossip envelope without
	// recomputation (see pkg/preconf/validation.go for the fork-gated
	// presence check).
	HeaderDifficulty *big.Int
}
