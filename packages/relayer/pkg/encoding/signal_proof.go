package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/pkg/errors"
)

func EncodeRLPSignalProof(signalProof RLPSignalProof) ([]byte, error) {
	args := abi.Arguments{
		{
			Type: rlpSignalProofT,
		},
	}

	encodedSignalProof, err := args.Pack(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedSignalProof, nil
}

func EncodeABISignalProof(signalProof ABISignalProof) ([]byte, error) {
	args := abi.Arguments{
		{
			Type: abiSignalProofT,
		},
	}

	encodedSignalProof, err := args.Pack(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedSignalProof, nil
}
