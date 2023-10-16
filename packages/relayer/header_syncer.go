package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/icrosschainsync"
)

type HeaderSyncer interface {
	GetSyncedSnippet(
		opts *bind.CallOpts,
		blockId uint64,
	) (icrosschainsync.ICrossChainSyncSnippet, error)
}
