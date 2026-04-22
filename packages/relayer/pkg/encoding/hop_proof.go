package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/pkg/errors"
)

func EncodeHopProofs(hopProofs []HopProof) ([]byte, error) {
	args := abi.Arguments{
		{
			Type: hopProofsT,
		},
	}

	encodedHopProofs, err := args.Pack(hopProofs)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedHopProofs, nil
}
