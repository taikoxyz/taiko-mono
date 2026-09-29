package derivation

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// validateManifestTransactions checks the execution encoding before retaining a source.
// One incompatible transaction invalidates the whole source, preserving the normal
// default-source path that inserts an anchor before handing the list to the engine.
func validateManifestTransactions(m *manifest.DerivationSourceManifest) error {
	for blockIndex, block := range m.Blocks {
		for txIndex, tx := range block.Transactions {
			if err := validateTransactionEncoding(tx); err != nil {
				return fmt.Errorf("block %d transaction %d: %w", blockIndex, txIndex, err)
			}
		}
	}
	return nil
}

// validateTransactionEncoding checks the grammar shared by the Rust manifest decoder
// and alethia-reth's execution transaction decoder. Signer recovery and execution
// validity are deliberately left to the engine.
func validateTransactionEncoding(tx *types.Transaction) error {
	switch tx.Type() {
	case types.LegacyTxType, types.AccessListTxType, types.DynamicFeeTxType,
		types.BlobTxType, types.SetCodeTxType:
	default:
		return fmt.Errorf("unsupported transaction type %d", tx.Type())
	}
	for _, field := range []struct {
		name  string
		value *big.Int
		bits  int
	}{
		{"maxFeePerGas", tx.GasFeeCap(), 128},
		{"maxPriorityFeePerGas", tx.GasTipCap(), 128},
		{"value", tx.Value(), 256},
	} {
		if field.value.Sign() < 0 || field.value.BitLen() > field.bits {
			return fmt.Errorf("%s exceeds uint%d", field.name, field.bits)
		}
	}
	v, r, s := tx.RawSignatureValues()
	if r.Sign() < 0 || r.BitLen() > 256 || s.Sign() < 0 || s.BitLen() > 256 {
		return fmt.Errorf("signature scalar exceeds uint256")
	}
	if tx.Type() == types.LegacyTxType {
		if v.Cmp(big.NewInt(27)) == 0 || v.Cmp(big.NewInt(28)) == 0 {
			return nil
		}
		if v.Cmp(big.NewInt(35)) < 0 {
			return fmt.Errorf("invalid legacy signature v")
		}
		chainID := new(big.Int).Rsh(new(big.Int).Sub(v, big.NewInt(35)), 1)
		if !chainID.IsUint64() {
			return fmt.Errorf("legacy chain ID exceeds uint64")
		}
		return nil
	}
	if !tx.ChainId().IsUint64() {
		return fmt.Errorf("chain ID exceeds uint64")
	}
	if v.Sign() < 0 || v.BitLen() > 1 {
		return fmt.Errorf("invalid typed transaction parity")
	}
	if tx.Type() == types.BlobTxType {
		if fee := tx.BlobGasFeeCap(); fee.Sign() < 0 || fee.BitLen() > 128 {
			return fmt.Errorf("maxFeePerBlobGas exceeds uint128")
		}
		if tx.BlobTxSidecar() != nil {
			return fmt.Errorf("blob sidecar wrapper is not an execution transaction")
		}
	}
	return nil
}
