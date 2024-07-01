package processor

import (
	"context"
	"encoding/hex"
	"log/slog"
	"strings"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
)

// retrySingle is used to retry a single message, when we are
// targeting a specific message via config flag
func (p *Processor) retrySingle(ctx context.Context) error {
	slog.Info("retrying single", "txHash", common.Hash(*p.targetTxHash).Hex())

	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return err
	}

	receipt, err := p.srcEthClient.TransactionReceipt(ctx, *p.targetTxHash)
	if err != nil {
		return err
	}

	for _, log := range receipt.Logs {
		topic := log.Topics[0]

		if topic == bridgeAbi.Events["MessageSent"].ID {
			event, err := p.destBridge.ParseMessageSent(*log)
			if err != nil {
				return err
			}

			data, err := encoding.BridgeABI.Pack("retryMessage", event.Message, false)
			if err != nil {
				return err
			}

			gasLimit := uint64(float64(event.Message.GasLimit) * 3)

			candidate := txmgr.TxCandidate{
				TxData:   data,
				Blobs:    nil,
				To:       &p.cfg.DestBridgeAddress,
				GasLimit: gasLimit,
			}

			receipt, err := p.txmgr.Send(ctx, candidate)
			if err != nil {
				slog.Warn("Failed to send ProcessMessage transaction", "error", err.Error())
				return err
			}

			slog.Info("Mined tx",
				"txHash", hex.EncodeToString(receipt.TxHash.Bytes()),
				"srcTxHash", event.Raw.TxHash.Hex(),
			)

			if receipt.Status != types.ReceiptStatusSuccessful {
				relayer.MessageSentEventsProcessedReverted.Inc()
				slog.Warn("Transaction reverted", "txHash", hex.EncodeToString(receipt.TxHash.Bytes()),
					"srcTxHash", event.Raw.TxHash.Hex(),
					"status", receipt.Status)

				return errTxReverted
			}

		}
	}

	return nil
}
