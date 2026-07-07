package utils

import (
	"bytes"
	"compress/zlib"
	"errors"
	"fmt"
	"io"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// EncodeAndCompress RLP-encodes the provided data and returns the zlib-compressed bytes.
// The descriptor clarifies the type of data in error messages.
func EncodeAndCompress[T any](data T, descriptor string) ([]byte, error) {
	b, err := rlp.EncodeToBytes(data)
	if err != nil {
		return nil, fmt.Errorf("failed to RLP encode %s: %w", descriptor, err)
	}

	compressed, err := Compress(b)
	if err != nil {
		return nil, fmt.Errorf("failed to compress RLP encoded %s: %w", descriptor, err)
	}

	return compressed, nil
}

// EncodeAndCompressTxList encodes and compresses the given transactions list using RLP encoding
// followed by zlib compression.
func EncodeAndCompressTxList(txs types.Transactions) ([]byte, error) {
	return EncodeAndCompress(txs, "transactions")
}

// EncodeAndCompressSourceManifest encodes and compresses the given derivation source manifest using RLP
// encoding followed by zlib compression.
func EncodeAndCompressSourceManifest(sourceManifest *manifest.DerivationSourceManifest) ([]byte, error) {
	return EncodeAndCompress(sourceManifest, "derivation source manifest")
}

// Compress compresses the given txList bytes using zlib.
func Compress(txList []byte) ([]byte, error) {
	var b bytes.Buffer
	w := zlib.NewWriter(&b)
	defer w.Close()

	if _, err := w.Write(txList); err != nil {
		return nil, err
	}

	if err := w.Close(); err != nil {
		return nil, err
	}

	return b.Bytes(), nil
}

// Decompress decompresses the given txList bytes using zlib, it checks the ErrUnexpectedEOF error.
func Decompress(compressedTxList []byte) ([]byte, error) {
	r, err := zlib.NewReader(bytes.NewBuffer(compressedTxList))
	if err != nil {
		return nil, err
	}
	defer r.Close()

	b, err := io.ReadAll(r)
	if err != nil {
		if !errors.Is(err, io.EOF) {
			return nil, err
		}
	}

	return b, nil
}
