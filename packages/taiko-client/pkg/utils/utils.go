package utils

import (
	"bytes"
	"compress/zlib"
	"errors"
	"fmt"
	"io"
	"math"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/joho/godotenv"
	"github.com/modern-go/reflect2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// LoadEnv loads all the test environment variables.
func LoadEnv() {
	currentPath, err := os.Getwd()
	if err != nil {
		log.Debug("Failed to get current path", "error", err)
	}
	path := strings.Split(currentPath, "/taiko-client")
	if len(path) == 0 {
		log.Debug("Not a taiko-client repo")
	}
	if godotenv.Load(fmt.Sprintf("%s/taiko-client/integration_test/.env", path[0])) != nil {
		log.Debug("Failed to load test env", "current path", currentPath, "error", err)
	}
}

// IsNil checks if the interface is empty.
func IsNil(i interface{}) bool {
	return reflect2.IsNil(i)
}

// EncodeAndCompressTxList encodes and compresses the given transactions list using RLP encoding
// followed by zlib compression.
func EncodeAndCompressTxList(txs types.Transactions) ([]byte, error) {
	b, err := rlp.EncodeToBytes(txs)
	if err != nil {
		return nil, fmt.Errorf("failed to RLP encode transactions: %w", err)
	}

	compressed, err := Compress(b)
	if err != nil {
		return nil, fmt.Errorf("failed to compress RLP encoded transactions: %w", err)
	}

	return compressed, nil
}

// EncodeAndCompressDerivationSourceShasta encodes and compresses the given Shasta derivation source using RLP encoding
// followed by zlib compression.
func EncodeAndCompressDerivationSourceShasta(proposal manifest.DerivationSourceManifest) ([]byte, error) {
	b, err := rlp.EncodeToBytes(proposal)
	if err != nil {
		return nil, fmt.Errorf("failed to RLP encode Shasta derivation source manifest: %w", err)
	}

	compressed, err := Compress(b)
	if err != nil {
		return nil, fmt.Errorf("failed to compress RLP encoded Shasta derivation source manifest: %w", err)
	}

	return compressed, nil
}

// EncodeAndCompressProposalManifestShasta encodes and compresses the given Shasta proposal manifest using RLP encoding
// followed by zlib compression.
func EncodeAndCompressProposalManifestShasta(proposal manifest.ProposalManifest) ([]byte, error) {
	b, err := rlp.EncodeToBytes(proposal)
	if err != nil {
		return nil, fmt.Errorf("failed to RLP encode Shasta proposal manifest: %w", err)
	}

	compressed, err := Compress(b)
	if err != nil {
		return nil, fmt.Errorf("failed to compress RLP encoded Shasta proposal manifest: %w", err)
	}

	return compressed, nil
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

// GWeiToWei converts gwei value to wei value.
func GWeiToWei(gwei float64) (*big.Int, error) {
	if math.IsNaN(gwei) || math.IsInf(gwei, 0) {
		return nil, fmt.Errorf("invalid gwei value: %v", gwei)
	}

	// convert float GWei value into integer Wei value
	wei, _ := new(big.Float).Mul(
		big.NewFloat(gwei),
		big.NewFloat(params.GWei)).
		Int(nil)

	if wei.Cmp(abi.MaxUint256) == 1 {
		return nil, errors.New("gwei value larger than max uint256")
	}

	return wei, nil
}

// EtherToWei converts ether value to wei value.
func EtherToWei(ether float64) (*big.Int, error) {
	if math.IsNaN(ether) || math.IsInf(ether, 0) {
		return nil, fmt.Errorf("invalid ether value: %v", ether)
	}

	// convert float GWei value into integer Wei value
	wei, _ := new(big.Float).Mul(
		big.NewFloat(ether),
		big.NewFloat(params.Ether)).
		Int(nil)

	if wei.Cmp(abi.MaxUint256) == 1 {
		return nil, errors.New("ether value larger than max uint256")
	}

	return wei, nil
}

// WeiToEther converts wei value to ether value.
func WeiToEther(wei *big.Int) *big.Float {
	return new(big.Float).Quo(new(big.Float).SetInt(wei), new(big.Float).SetInt(big.NewInt(params.Ether)))
}

// WeiToGWei converts wei value to gwei value.
func WeiToGWei(wei *big.Int) *big.Float {
	return new(big.Float).Quo(new(big.Float).SetInt(wei), new(big.Float).SetInt(big.NewInt(params.GWei)))
}
