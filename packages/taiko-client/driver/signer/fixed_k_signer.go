package signer

import (
	"fmt"

	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

var (
	// 32 zero bytes.
	zero32 [32]byte
)

// FixedKSigner is a ethereum ECDSA signer who always sign payload with the given K value.
// In theory K value is randomly selected in ECDSA algorithm's step 3:
// https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm,
// but here we use a fixed K value instead.
type FixedKSigner struct {
	privKey *secp256k1.ModNScalar
}

func NewFixedKSigner(privKey string) (*FixedKSigner, error) {
	var priv btcec.PrivateKey
	if overflow := priv.Key.SetByteSlice(hexutil.MustDecode(privKey)); overflow || priv.Key.IsZero() {
		return nil, fmt.Errorf("invalid private key %s", privKey)
	}

	return &FixedKSigner{privKey: &priv.Key}, nil
}

// SignWithK signs the given hash using fixed K.
func (s *FixedKSigner) SignWithK(k *secp256k1.ModNScalar) func(hash []byte) ([]byte, bool) {
	// k * G
	var kG secp256k1.JacobianPoint
	secp256k1.ScalarBaseMultNonConst(k, &kG)
	kG.ToAffine()

	// r = kG.X mod N
	// r != 0
	r, overflow := fieldToModNScalar(&kG.X)
	pubKeyRecoveryCode := byte(overflow<<1) | byte(kG.Y.IsOddBit())

	kinv := new(secp256k1.ModNScalar).InverseValNonConst(k)
	_s := new(secp256k1.ModNScalar).Mul2(s.privKey, &r)

	return func(hash []byte) ([]byte, bool) {
		var e secp256k1.ModNScalar
		e.SetByteSlice(hash)
		// copy _s here to avoid modifying the original one.
		_s := *_s
		s := _s.Add(&e).Mul(kinv)
		if s.IsZero() {
			return nil, false
		}
		// copy pubKeyRecoveryCode here to avoid modifying the original one.
		pubKeyRecoveryCode := pubKeyRecoveryCode
		if s.IsOverHalfOrder() {
			s.Negate()

			pubKeyRecoveryCode ^= 0x01
		}

		var sig [65]byte // r(32) + s(32) + v(1)
		r.PutBytesUnchecked(sig[:32])
		s.PutBytesUnchecked(sig[32:64])
		sig[64] = pubKeyRecoveryCode
		return sig[:], true
	}
}

// fieldToModNScalar converts a `secp256k1.FieldVal` to `secp256k1.ModNScalar`.
func fieldToModNScalar(v *secp256k1.FieldVal) (secp256k1.ModNScalar, uint32) {
	var buf [32]byte
	v.PutBytes(&buf)
	var s secp256k1.ModNScalar
	overflow := s.SetBytes(&buf)
	// Clear buf here maybe for preventing memory theft (copy from source)
	resetBuffer(&buf)
	return s, overflow
}

// resetBuffer resets the given buffer.
func resetBuffer(b *[32]byte) {
	copy(b[:], zero32[:])
}
