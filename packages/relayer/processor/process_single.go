package processor

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

// processSingle is used to process a single message, when we are
// targeting a specific message via config flag
func (p *Processor) processSingle(ctx context.Context) error {
	slog.Info("processing single", "txHash", common.Hash(*p.targetTxHash).Hex())

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

			msg := queue.QueueMessageSentBody{
				ID:    0,
				Event: event,
			}

			marshalledMsg, err := json.Marshal(msg)
			if err != nil {
				return err
			}

			if _, err := p.processMessage(ctx, queue.Message{
				Body: marshalledMsg,
			}); err != nil {
				return err
			}
		}
	}

	return nil
}
