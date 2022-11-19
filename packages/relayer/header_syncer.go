package relayer

import "github.com/ethereum/go-ethereum/accounts/abi/bind"

type HeaderSyncer interface {
	GetLatestSyncedHeader(opts *bind.CallOpts) ([32]byte, error)
}
