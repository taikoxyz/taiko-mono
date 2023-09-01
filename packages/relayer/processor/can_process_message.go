package processor

import (
	"context"
	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func canProcessMessage(
	ctx context.Context,
	eventStatus relayer.EventStatus,
	messageOwner common.Address,
	relayerAddress common.Address,
) bool {
	// we can not process, exit early
	if eventStatus == relayer.EventStatusNewOnlyOwner {
		if messageOwner != relayerAddress {
			slog.Info("gasLimit == 0 and owner is not the current relayer key, can not process. continuing loop")
			return false
		}

		return true
	}

	if eventStatus == relayer.EventStatusNew {
		return true
	}

	slog.Info("cant process message", "eventStatus", eventStatus.String())

	return false
}
