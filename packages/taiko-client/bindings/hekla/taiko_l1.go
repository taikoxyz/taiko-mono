package hekla

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// BlockVerifiedEvent mirrors the Solidity event:
//
//	event BlockVerified(
//	  uint256 indexed blockId,
//	  address indexed assignedProver,
//	  address indexed prover,
//	  bytes32 blockHash,
//	  bytes32 signalRoot,
//	  uint16 tier,
//	  uint8 contestations
//	);
type BlockVerifiedEvent struct {
	BlockId        *big.Int
	AssignedProver common.Address
	Prover         common.Address
	BlockHash      [32]byte
	SignalRoot     [32]byte
	Tier           uint16
	Contestations  uint8
	Raw            types.Log
}

// FilterBlockVerifiedHekla fetches BlockVerified events from the Taiko L1 contract
// and is necessary because Hekla has a Hekla-specific genesis verification event.
func FilterBlockVerifiedHekla(
	ctx context.Context,
	client *ethclient.Client,
	taikoL1 common.Address,
	fromBlock, toBlock *big.Int,
) ([]BlockVerifiedEvent, error) {
	// 1. Compute the event signature hash
	eventSignature := []byte("BlockVerified(uint256,address,address,bytes32,bytes32,uint16,uint8)")
	eventSigHash := crypto.Keccak256Hash(eventSignature)

	// 2. Build the filter query
	query := ethereum.FilterQuery{
		FromBlock: fromBlock,
		ToBlock:   toBlock,
		Addresses: []common.Address{taikoL1},
		Topics:    [][]common.Hash{{eventSigHash}},
	}

	// 3. Fetch raw logs
	logs, err := client.FilterLogs(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("FilterLogs error: %w", err)
	}

	abiJSON := `[{"anonymous":false,"inputs":[
	  {"indexed":true,"internalType":"uint256","name":"blockId","type":"uint256"},
	  {"indexed":true,"internalType":"address","name":"assignedProver","type":"address"},
	  {"indexed":true,"internalType":"address","name":"prover","type":"address"},
	  {"indexed":false,"internalType":"bytes32","name":"blockHash","type":"bytes32"},
	  {"indexed":false,"internalType":"bytes32","name":"signalRoot","type":"bytes32"},
	  {"indexed":false,"internalType":"uint16","name":"tier","type":"uint16"},
	  {"indexed":false,"internalType":"uint8","name":"contestations","type":"uint8"}
	],"name":"BlockVerified","type":"event"}]`

	contractABI, err := abi.JSON(strings.NewReader(abiJSON))
	if err != nil {
		return nil, fmt.Errorf("ABI parsing error: %w", err)
	}

	// 5. Iterate over each log and unpack
	var events []BlockVerifiedEvent
	for _, vLog := range logs {
		var ev BlockVerifiedEvent
		ev.Raw = vLog

		// Indexed fields: Topics[1], Topics[2], Topics[3]
		ev.BlockId = new(big.Int).SetBytes(vLog.Topics[1].Bytes())
		ev.AssignedProver = common.BytesToAddress(vLog.Topics[2].Bytes())
		ev.Prover = common.BytesToAddress(vLog.Topics[3].Bytes())

		// Non-indexed fields: decode from vLog.Data
		outs, err := contractABI.Unpack("BlockVerified", vLog.Data)
		if err != nil {
			return nil, fmt.Errorf("ABI unpack error: %w", err)
		}
		ev.BlockHash = outs[0].([32]byte)
		ev.SignalRoot = outs[1].([32]byte)
		ev.Tier = outs[2].(uint16)
		ev.Contestations = outs[3].(uint8)

		events = append(events, ev)
	}

	return events, nil
}
