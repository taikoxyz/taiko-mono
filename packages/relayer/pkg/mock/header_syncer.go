package mock

import (
	"errors"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/icrosschainsync"
)

var SuccessHeader = icrosschainsync.ICrossChainSyncSnippet{
	BlockHash: [32]byte{0x1},
	StateRoot: [32]byte{0x2},
}

type HeaderSyncer struct {
	Fail bool
}

func (h *HeaderSyncer) GetSyncedSnippet(
	opts *bind.CallOpts,
	blockId uint64,
) (icrosschainsync.ICrossChainSyncSnippet, error) {
	if h.Fail {
		return icrosschainsync.ICrossChainSyncSnippet{}, errors.New("fail")
	}

	return SuccessHeader, nil
}
