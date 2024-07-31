package preconfapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
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
		preconfBlock, err := p.ethclient.BlockByNumber(context.Background(), new(big.Int).SetUint64(latestBlockNumber))
		if err != nil {
			return err
		}

		for _, tx := range preconfBlock.Transactions() {
			if err := p.db.Update(func(txn *badger.Txn) error {
				_, err := txn.Get(tx.Hash().Bytes())
				if err == nil {
					return nil
				}

				receipt, err := p.ethclient.TransactionReceipt(p.ctx, tx.Hash())
				if err != nil {
					return err
				}

				sender, err := p.ethclient.TransactionSender(p.ctx, tx, preconfBlock.Hash(), receipt.TransactionIndex)
				if err != nil {
					return err
				}

				fromAddress := model.AddressParam{
					Hash:       sender.Hex(),
					IsContract: false,
				}

				toAddress := &model.AddressParam{
					Hash:       "",
					IsContract: false,
				}
				if tx.To() != nil {
					to := tx.To()
					toAddress.Hash = to.Hex()
					code, err := p.ethclient.CodeAt(p.ctx, *to, nil)
					if err != nil {
						return err
					}

					toAddress.IsContract = len(code) > 2
				}

				status := "ok"
				if receipt.Status != 1 {
					status = "error"
				}

				baseFee := preconfBlock.BaseFee().String()

				maxFeePerGas := tx.GasFeeCap().String()

				maxPrioFee := tx.GasTipCap().String()

				ts := tx.Time().UTC().Format("2006-01-02T15:04:05.000000Z")

				txType := int(tx.Type())

				txTypes := []model.TransactionType{}
				if toAddress.IsContract {
					txTypes = append(txTypes, model.TxTypeContractCall)
				} else {
					txTypes = append(txTypes, model.TxTypeCoinTransfer)
				}

				if tx.To() == nil {
					txTypes = append(txTypes, model.TxTypeContractCreation)
				}

				rawInput := common.Bytes2Hex(tx.Data())
				if rawInput == "" {
					rawInput = "0x"
				}

				modelTx := model.Transaction{
					Actions: make([]model.TxAction, 0),
					From:    fromAddress,
					To:      toAddress,
					Fee: model.Fee{
						Type:  "actual",
						Value: new(big.Int).Mul(tx.GasPrice(), new(big.Int).SetUint64(receipt.GasUsed)).String(),
					},
					Hash:                 tx.Hash().Hex(),
					Value:                tx.Value().String(),
					GasPrice:             tx.GasPrice().String(),
					Nonce:                int(tx.Nonce()),
					Block:                new(int),
					GasLimit:             tx.Gas(),
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

				err = txn.Set(tx.Hash().Bytes(), marshalled)
				if err != nil {
					log.Error("Failed to set transaction in BadgerDB", "error", err)
					return err
				}

				return nil
			}); err != nil {
				return err
			}

			log.Info("saved tx", "hash", tx.Hash().Hex())
		}
	}

	p.latestSeenBlockNumber = latestBlockNumber

	return nil
}
