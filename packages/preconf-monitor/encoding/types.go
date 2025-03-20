package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/bindings/preconfwhitelist"
)

var PreconfWhitelistABI *abi.ABI

func init() {
	var err error

	if PreconfWhitelistABI, err = preconfwhitelist.PreconfWhitelistMetaData.GetAbi(); err != nil {
		log.Crit("Get PreconfWhitelist ABI error", "error", err)
	}
}
