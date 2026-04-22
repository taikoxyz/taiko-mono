package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"

	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikotoken"
)

var TaikoTokenABI *abi.ABI

var err error

func init() {
	if TaikoTokenABI, err = taikotoken.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoTokenABI ABI error", "error", err)
	}
}
