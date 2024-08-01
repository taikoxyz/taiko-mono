package preconfapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/model"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/server"

	badger "github.com/dgraph-io/badger/v4"
)

type PreconfAPI struct {
	cfg                   *Config
	server                *server.PreconfAPIServer
	wg                    *sync.WaitGroup
	ctx                   context.Context
	ethclient             *ethclient.Client
	latestSeenBlockNumber uint64
	chainID               *big.Int
	db                    *badger.DB
}

// InitFromCli New initializes the given proposer instance based on the command line flags.
func (p *PreconfAPI) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return p.InitFromConfig(ctx, cfg)
}

func (p *PreconfAPI) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	txBuilders := make(map[string]builder.TxBuilder)
	txBuilders["blob"] = builder.NewBlobTransactionBuilder(
		cfg.TaikoL1Address,
		cfg.ProposeBlockTxGasLimit,
	)

	txBuilders["calldata"] = builder.NewCalldataTransactionBuilder(
		cfg.TaikoL1Address,
		cfg.ProposeBlockTxGasLimit,
	)

	p.cfg = cfg
	p.wg = &sync.WaitGroup{}
	p.ctx = ctx

	p.ethclient, err = ethclient.DialContext(ctx, cfg.L2HTTPEndpoint)
	if err != nil {
		return err
	}

	// get latest block number from L2
	p.latestSeenBlockNumber, err = p.ethclient.BlockNumber(ctx)
	if err != nil {
		return err
	}

	p.chainID, err = p.ethclient.ChainID(ctx)
	if err != nil {
		return err
	}

	p.db, err = badger.Open(badger.DefaultOptions(p.cfg.DBPath))
	if err != nil {
		return err
	}

	if p.server, err = server.New(&server.NewPreconfAPIServerOpts{
		TxBuilders: txBuilders,
		DB:         p.db,
	}); err != nil {
		return err
	}

	return nil
}

func (p *PreconfAPI) Start() error {
	p.wg.Add(1)
	go p.pollLoop(p.ctx)

	go func() {
		if err := p.server.Start(fmt.Sprintf(":%v", p.cfg.HTTPPort)); !errors.Is(err, http.ErrServerClosed) {
			log.Crit("Failed to start http server", "error", err)
		}
	}()

	return nil
}

// Close closes the proposer instance.
func (p *PreconfAPI) Close(ctx context.Context) {
	if err := p.server.Shutdown(ctx); err != nil {
		log.Error("Failed to shut down prover server", "error", err)
	}

	p.db.Close()

	p.wg.Wait()
}

func (p *PreconfAPI) Name() string {
	return "preconfapi"
}

func (p *PreconfAPI) pollLoop(ctx context.Context) {
	defer p.wg.Done()

	t := time.NewTicker(p.cfg.PollingInterval)

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := p.poll(); err != nil {
				log.Error("Failed to poll", "error", err)
			}
		}
	}
}

func (p *PreconfAPI) poll() error {
	// get latest block number from L2
	latestBlockNumber, err := p.ethclient.BlockNumber(context.Background())
	if err != nil {
		return err
	}

	if latestBlockNumber < p.latestSeenBlockNumber {
		return nil
	}

	for i := p.latestSeenBlockNumber; i <= latestBlockNumber; i++ {
		var result json.RawMessage
		err := p.ethclient.Client().CallContext(
			context.Background(),
			&result,
			"eth_getBlockByNumber",
			fmt.Sprintf("0x%v", new(big.Int).SetUint64(latestBlockNumber).Text(16)),
			true,
		)
		if err != nil {
			return err
		}

		var preconfBlock CustomBlock
		err = json.Unmarshal(result, &preconfBlock)
		if err != nil {
			return err
		}

		for _, tx := range preconfBlock.Transactions {
			if err := p.db.Update(func(txn *badger.Txn) error {
				_, err := txn.Get(common.HexToHash(tx.Hash).Bytes())
				if err == nil {
					return nil
				}

				receipt, err := p.ethclient.TransactionReceipt(p.ctx, common.Hash(common.HexToHash(tx.Hash).Bytes()))
				if err != nil {
					return err
				}

				fromAddress := model.AddressParam{
					Hash:       tx.From,
					IsContract: false,
				}

				toAddress := &model.AddressParam{
					Hash:       "",
					IsContract: false,
				}
				if tx.To != nil {
					to := tx.To
					toAddress.Hash = *to
					code, err := p.ethclient.CodeAt(p.ctx, common.HexToAddress(*to), nil)
					if err != nil {
						return err
					}

					toAddress.IsContract = len(code) > 2
				}

				status := "ok"
				if receipt.Status != 1 {
					status = "error"
				}

				maxFeePerGas := tx.MaxFeePerGas

				maxPrioFee := tx.MaxPriorityFeePerGas

				ts := time.Now().UTC().Format("2006-01-02T15:04:05.000000Z")

				txT, err := strconv.ParseInt(tx.Type, 0, 64)
				if err != nil {
					return err
				}

				txType := int(txT)

				nonceT, err := strconv.ParseInt(tx.Nonce, 0, 64)
				if err != nil {
					return err
				}

				nonce := int(nonceT)

				txTypes := []model.TransactionType{}
				if toAddress.IsContract {
					txTypes = append(txTypes, model.TxTypeContractCall)
				} else {
					txTypes = append(txTypes, model.TxTypeCoinTransfer)
				}

				if tx.To == nil {
					txTypes = append(txTypes, model.TxTypeContractCreation)
				}

				rawInput := common.Bytes2Hex([]byte(tx.Input))
				if rawInput == "" {
					rawInput = "0x"
				}

				baseFee := "1" // TODO

				gpT, err := strconv.ParseInt(tx.GasPrice, 0, 64)
				if err != nil {
					return err
				}

				gas, err := strconv.ParseInt(tx.Gas, 0, 64)
				if err != nil {
					return err
				}

				modelTx := model.Transaction{
					Actions: make([]model.TxAction, 0),
					From:    fromAddress,
					To:      toAddress,
					Fee: model.Fee{
						Type:  "actual",
						Value: new(big.Int).Mul(new(big.Int).SetInt64(gpT), new(big.Int).SetUint64(receipt.GasUsed)).String(),
					},
					Hash:                 tx.Hash,
					Value:                tx.Value,
					GasPrice:             tx.GasPrice,
					Nonce:                nonce,
					Block:                new(int),
					GasLimit:             uint64(gas),
					TxTypes:              txTypes,
					Status:               &status,
					Confirmations:        int(latestBlockNumber) - int(receipt.BlockNumber.Uint64()),
					GasUsed:              &receipt.GasUsed,
					MaxFeePerGas:         &maxFeePerGas,
					MaxPriorityFeePerGas: &maxPrioFee,
					BaseFeePerGas:        &baseFee,
					Position:             &receipt.TransactionIndex,
					Timestamp:            &ts,
					ConfirmationDuration: []int{},
					RawInput:             rawInput,
					Type:                 &txType,
					// Add other fields as necessary
				}

				*modelTx.Block = int(latestBlockNumber)

				marshalled, err := json.Marshal(modelTx)
				if err != nil {
					return err
				}

				err = txn.Set(common.HexToHash(tx.Hash).Bytes(), marshalled)
				if err != nil {
					log.Error("Failed to set transaction in BadgerDB", "error", err)
					return err
				}

				log.Info("saved tx", "hash", common.HexToHash(tx.Hash))

				return nil
			}); err != nil {
				return err
			}
		}
	}

	p.latestSeenBlockNumber = latestBlockNumber

	return nil
}
