package preconf

import "github.com/ethereum-optimism/optimism/op-service/eth"

type Envelope struct {
	Payload           *eth.ExecutionPayload
	IsForcedInclusion bool
	Signature         *[65]byte
}
