import axios from 'axios';
import { BigNumber, Contract, ethers } from 'ethers';
import Bridge from '../constants/abi/Bridge';
import ERC20 from '../constants/abi/ERC20';
import TokenVault from '../constants/abi/TokenVault';
import { chains } from '../domain/chain';
import { MessageStatus } from '../domain/message';

import type { BridgeTransaction } from '../domain/transactions';
import { chainIdToTokenVaultAddress } from '../store/bridge';
import { get } from 'svelte/store';
import type { RelayerAPI, RelayerBlockInfo } from 'src/domain/relayerApi';

class RelayerAPIService implements RelayerAPI {
  private readonly providerMap: Map<number, ethers.providers.JsonRpcProvider>;
  private readonly baseUrl: string;
  constructor(providerMap: Map<number, ethers.providers.JsonRpcProvider>, baseUrl: string) {
    this.providerMap = providerMap;
    this.baseUrl = baseUrl;
  }

  async GetAllByAddress(address: string, chainID?: number): Promise<BridgeTransaction[]> {
    if(!address) {
     throw new Error("Address need to passed to fetch transactions");
    }
    const params = {
      address,
      chainID,
    }

    const requestURL = `${this.baseUrl}events`;
    
    const { data } = await axios.get(requestURL, { params });

    if(data.length === 0) {
      return [];
    }

    const txs: BridgeTransaction[] = data.map((tx) => {
      const depositValue = ethers.utils.parseUnits(tx.data.Message.DepositValue.toString(), 'wei');
      return {
        status: tx.status,
        message: {
          id: tx.data.Message.Id,
          to: tx.data.Message.To,
          data: tx.data.Message.Data,
          memo: tx.data.Message.Memo,
          owner: tx.data.Message.Owner,
          sender: tx.data.Message.Sender,
          gasLimit: BigNumber.from(tx.data.Message.GasLimit),
          callValue: tx.data.Message.CallValue,
          srcChainId: BigNumber.from(tx.data.Message.SrcChainId),
          destChainId: BigNumber.from(tx.data.Message.DestChainId),
          depositValue: depositValue,
          processingFee: BigNumber.from(tx.data.Message.ProcessingFee),
          refundAddress: tx.data.Message.RefundAddress,
        },
        amountInWei: tx.amount,
        symbol: tx.canonicalTokenSymbol,
        fromChainId: tx.data.Message.SrcChainId,
        toChainId: tx.data.Message.DestChainId,
        hash: tx.data.Raw.transactionHash,
        from: tx.data.Message.Owner,
      }
    })

    const bridgeTxs: BridgeTransaction[] = [];

    await Promise.all(
      (txs || []).map(async (tx) => {
        if (tx.message.owner.toLowerCase() !== address.toLowerCase()) return;

        const destChainId = tx.toChainId;
        const destProvider = this.providerMap.get(destChainId);

        const srcProvider = this.providerMap.get(tx.fromChainId);

        const receipt = await srcProvider.getTransactionReceipt(
          tx.hash
        );

        if (!receipt) {
          bridgeTxs.push(tx);
          return;
        }

        tx.receipt = receipt;

        const destBridgeAddress = chains[destChainId].bridgeAddress;

        const srcBridgeAddress = chains[tx.fromChainId].bridgeAddress;

        const destContract: Contract = new Contract(
          destBridgeAddress,
          Bridge,
          destProvider
        );

        const srcContract: Contract = new Contract(
          srcBridgeAddress,
          Bridge,
          srcProvider
        );

        const events = await srcContract.queryFilter(
          "MessageSent",
          receipt.blockNumber,
          receipt.blockNumber
        );

        const event = events.find(
          (e) => e.args.message.owner.toLowerCase() === address.toLowerCase()
        );

        if (!event) {
          bridgeTxs.push(tx);
          return;
        }

        const msgHash = event.args.msgHash;

        const messageStatus: number = await destContract.getMessageStatus(
          msgHash
        );

        let amountInWei: BigNumber;
        let symbol: string;
        if (event.args.message.data !== "0x") {
          const tokenVaultContract = new Contract(
            get(chainIdToTokenVaultAddress).get(tx.fromChainId),
            TokenVault,
            srcProvider
          );
          const filter = tokenVaultContract.filters.ERC20Sent(msgHash)
          const erc20Events = await tokenVaultContract.queryFilter(
            filter,
            receipt.blockNumber,
            receipt.blockNumber
          );

          const erc20Event = erc20Events.find(
            (e) => e.args.msgHash.toLowerCase() === msgHash.toLowerCase()
          );
          if (!erc20Event) return;

          const erc20Contract = new Contract(
            erc20Event.args.token,
            ERC20,
            srcProvider
          );
          symbol = await erc20Contract.symbol();
          amountInWei = BigNumber.from(erc20Event.args.amount);
        }

        const bridgeTx: BridgeTransaction = {
          message: event.args.message,
          receipt: receipt,
          msgHash: event.args.msgHash,
          status: messageStatus,
          amountInWei: amountInWei,
          symbol: symbol,
          fromChainId: tx.fromChainId,
          toChainId: tx.toChainId,
          hash: tx.hash,
          from: tx.from,
        };

        bridgeTxs.push(bridgeTx);
      })
    );

    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return bridgeTxs;
  }

  async GetBlockInfo(): Promise<Map<number, RelayerBlockInfo>> {
    const requestURL = `${this.baseUrl}blockInfo`;
    const { data } = await axios.get(requestURL);
    const blockInfoMap: Map<number, RelayerBlockInfo> = new Map();
    if(data?.data.length > 0) {
      data.data.forEach((blockInfoByChain => {
        blockInfoMap.set(blockInfoByChain.chainID, blockInfoByChain);
      }));
    }

    return blockInfoMap;
  }

}

export default RelayerAPIService;