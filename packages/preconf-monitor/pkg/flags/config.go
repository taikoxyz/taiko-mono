package flags

import (
	"crypto/ecdsa"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/urfave/cli/v2"
)

// InitTxmgrConfigsFromCli initializes the transaction manager configs from the command line flags.
func InitTxmgrConfigsFromCli(l1Endpoint string, privateKey *ecdsa.PrivateKey, c *cli.Context) *txmgr.CLIConfig {
	return &txmgr.CLIConfig{
		L1RPCURL:                  l1Endpoint,
		PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(privateKey)),
		NumConfirmations:          c.Uint64(flags.NumConfirmations.Name),
		SafeAbortNonceTooLowCount: c.Uint64(flags.SafeAbortNonceTooLowCount.Name),
		FeeLimitMultiplier:        c.Uint64(flags.FeeLimitMultiplier.Name),
		FeeLimitThresholdGwei:     c.Float64(flags.FeeLimitThreshold.Name),
		MinBaseFeeGwei:            c.Float64(flags.MinBaseFee.Name),
		MinTipCapGwei:             c.Float64(flags.MinTipCap.Name),
		ResubmissionTimeout:       c.Duration(flags.ResubmissionTimeout.Name),
		NetworkTimeout:            c.Duration(flags.RPCTimeout.Name),
		ReceiptQueryInterval:      c.Duration(flags.ReceiptQueryInterval.Name),
		TxSendTimeout:             c.Duration(flags.TxSendTimeout.Name),
		TxNotInMempoolTimeout:     c.Duration(flags.TxNotInMempoolTimeout.Name),
	}
}
