package guardianproverhealthcheck

import (
	"encoding/base64"
	"errors"
	"log/slog"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/prometheus/client_golang/prometheus"
)

type GuardianProver struct {
	Address            common.Address
	ID                 *big.Int
	HealthCheckCounter prometheus.Counter
	SignedBlockCounter prometheus.Counter
}

func SignatureToGuardianProver(
	msg []byte,
	b64EncodedSig string,
	guardianProvers []GuardianProver,
) (*GuardianProver, error) {
	b64DecodedSig, err := base64.StdEncoding.DecodeString(b64EncodedSig)
	if err != nil {
		return nil, err
	}

	// recover the public key from the signature
	r, err := crypto.SigToPub(msg, b64DecodedSig)
	if err != nil {
		return nil, err
	}

	// convert it to address type
	recoveredAddr := crypto.PubkeyToAddress(*r)

	// see if any of our known guardian provers have that recovered address
	for _, p := range guardianProvers {
		if recoveredAddr.Cmp(p.Address) == 0 {
			return &p, nil
		}
	}

	slog.Error("signature does not recover to known guardian prover",
		"recovered", recoveredAddr.Hex(),
		"guardianProvers", guardianProvers,
	)

	return nil, errors.New("signature does not recover to known guardian prover")
}
