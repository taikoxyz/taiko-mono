package indexer

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"log/slog"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

const erc20ABI = `[{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"}]`

const transferEventABI = `[{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]`

// indexERc20Transfers indexes from a given starting block to a given end block and parses all event logs
// to find ERC20 transfer events and update balances
func (i *Indexer) indexERC20Transfers(
	ctx context.Context,
	chainID *big.Int,
	logs []types.Log,
) error {
	for _, vLog := range logs {
		if !i.isERC20Transfer(ctx, vLog) {
			continue
		}

		if err := i.saveERC20Transfer(ctx, chainID, vLog); err != nil {
			return err
		}
	}

	return nil
}

// isERC20Transfer determines whether a given log is a valid ERC20 transfer event
func (i *Indexer) isERC20Transfer(ctx context.Context, vLog types.Log) bool {
	// malformed event
	if len(vLog.Topics) == 0 {
		return false
	}

	// the first topic is ALWAYS the hash of the event signature.
	// this is how people are expected to look up which event is which.
	if vLog.Topics[0].Hex() != logTransferSigHash.Hex() {
		return false
	}

	// erc20 transfer length will be 3, nft will be 4, only way to
	// differentiate them
	if len(vLog.Topics) != 3 {
		return false
	}

	return true
}

// saveERC20Transfer updates the user's balances on the from and to of a ERC20 transfer event
func (i *Indexer) saveERC20Transfer(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	from := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[1].Bytes()[12:]))

	to := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[2].Bytes()[12:]))

	event := struct {
		From  common.Address
		To    common.Address
		Value *big.Int
	}{}

	// Parse the Transfer event ABI
	parsedABI, err := abi.JSON(strings.NewReader(transferEventABI))
	if err != nil {
		return err
	}

	err = parsedABI.UnpackIntoInterface(&event, "Transfer", vLog.Data)
	if err != nil {
		return err
	}

	amount := event.Value.Int64()

	slog.Info(
		"erc20 transfer found",
		"from", from,
		"to", to,
		"amount", event.Value.Int64(),
		"contractAddress", vLog.Address.Hex(),
	)

	pk, err := i.erc20BalanceRepo.FindMetadata(ctx, chainID.Int64(), vLog.Address.Hex())
	if err != nil {
		return err
	}

	if pk == 0 {
		symbol, err := getERC20Symbol(ctx, i.ethClient, vLog.Address.Hex())
		if err != nil {
			return err
		}

		pk, err = i.erc20BalanceRepo.CreateMetadata(ctx, chainID.Int64(), vLog.Address.Hex(), symbol)
		if err != nil {
			return err
		}

		slog.Info("metadata created", "pk", pk, "symbol", symbol, "contractAddress", vLog.Address.Hex())
	} else {
		slog.Info("metadata found", "pk", pk, "contractAddress", vLog.Address.Hex())
	}

	// increment To address's balance
	// decrement From address's balance
	increaseOpts := eventindexer.UpdateERC20BalanceOpts{
		ERC20MetadataID: int64(pk),
		ChainID:         chainID.Int64(),
		Address:         to,
		ContractAddress: vLog.Address.Hex(),
		Amount:          amount,
	}

	decreaseOpts := eventindexer.UpdateERC20BalanceOpts{}

	// ignore zero address since that is usually the "mint"
	if from != ZeroAddress.Hex() {
		decreaseOpts = eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         chainID.Int64(),
			Address:         from,
			ContractAddress: vLog.Address.Hex(),
			Amount:          amount,
		}
	}

	_, _, err = i.erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx, increaseOpts, decreaseOpts)
	if err != nil {
		return err
	}

	return nil
}

func getERC20Symbol(ctx context.Context, client *ethclient.Client, contractAddress string) (string, error) {
	// Parse the contract address
	address := common.HexToAddress(contractAddress)

	// Parse the ERC20 contract ABI
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return "", err
	}

	// Prepare the call message
	callData, err := parsedABI.Pack("symbol")
	if err != nil {
		return "", err
	}

	msg := ethereum.CallMsg{
		To:   &address,
		Data: callData,
	}

	// Call the contract
	result, err := client.CallContract(ctx, msg, nil)
	if err != nil {
		return "", err
	}

	// Parse the result
	var symbol string
	err = parsedABI.UnpackIntoInterface(&symbol, "symbol", result)
	if err != nil {
		return "", err
	}

	return symbol, nil
}
