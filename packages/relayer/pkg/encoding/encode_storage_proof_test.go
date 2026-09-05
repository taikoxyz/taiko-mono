package encoding

import (
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// storageProofArgs mirrors what EncodeStorageProof packs, so a test can unpack the result and
// check the bridge would read back exactly what went in.
func storageProofArgs() abi.Arguments {
	return abi.Arguments{{Type: bytesArrayT}, {Type: bytesArrayT}}
}

func Test_EncodeStorageProof(t *testing.T) {
	accountProof := [][]byte{{0x01, 0x02}, {0x03}}
	storageProof := [][]byte{{0xaa, 0xbb, 0xcc}}

	encoded, err := EncodeStorageProof(accountProof, storageProof)

	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// The encoding is what the destination bridge verifies the message against, so the round trip
	// has to preserve both proofs and their order.
	decoded, err := storageProofArgs().Unpack(encoded)

	require.NoError(t, err)
	require.Len(t, decoded, 2)
	assert.Equal(t, accountProof, decoded[0])
	assert.Equal(t, storageProof, decoded[1])
}

func Test_EncodeStorageProofIsDeterministic(t *testing.T) {
	accountProof := [][]byte{{0x01}}
	storageProof := [][]byte{{0x02}}

	first, err := EncodeStorageProof(accountProof, storageProof)
	require.NoError(t, err)

	second, err := EncodeStorageProof(accountProof, storageProof)
	require.NoError(t, err)

	assert.Equal(t, first, second)
}

func Test_EncodeStorageProofAcceptsEmptyProofs(t *testing.T) {
	// A proof of zero length is still a well-formed encoding rather than an error; the bridge is
	// what decides the proof is insufficient.
	encoded, err := EncodeStorageProof([][]byte{}, [][]byte{})

	require.NoError(t, err)

	decoded, err := storageProofArgs().Unpack(encoded)

	require.NoError(t, err)
	require.Len(t, decoded, 2)
	assert.Empty(t, decoded[0])
	assert.Empty(t, decoded[1])
}
