package indexer

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/assert"
)

func TestIsERC20Transfer(t *testing.T) {
	token := common.HexToAddress("0x73FaC9201494f0bd17B9892B9fae4d52fe3BD377")
	from := common.BytesToHash(common.HexToAddress("0x1").Bytes())
	to := common.BytesToHash(common.HexToAddress("0x2").Bytes())
	tokenID := common.BigToHash(common.Big1)

	tests := []struct {
		name string
		log  types.Log
		want bool
	}{
		{
			name: "token transfer",
			log:  types.Log{Address: token, Topics: []common.Hash{logTransferSigHash, from, to}},
			want: true,
		},
		{
			// EIP-7708 ETH transfer logs share the ERC20 Transfer signature and topic count,
			// but the system address has no code to answer symbol() or decimals().
			name: "eip-7708 eth transfer",
			log:  types.Log{Address: params.SystemAddress, Topics: []common.Hash{logTransferSigHash, from, to}},
			want: false,
		},
		{
			name: "nft transfer",
			log:  types.Log{Address: token, Topics: []common.Hash{logTransferSigHash, from, to, tokenID}},
			want: false,
		},
		{
			name: "other event",
			log:  types.Log{Address: token, Topics: []common.Hash{common.HexToHash("0x1234"), from, to}},
			want: false,
		},
		{
			name: "no topics",
			log:  types.Log{Address: token},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, (&Indexer{}).isERC20Transfer(context.Background(), tt.log))
		})
	}
}
