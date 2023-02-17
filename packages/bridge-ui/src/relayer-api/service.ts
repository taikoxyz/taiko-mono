import axios from 'axios';
import type { Chain } from '@wagmi/core';
import type { ethers } from 'ethers';

import type { BridgeTransaction } from 'src/domain/transactions';

class RelayerAPIService {
  private readonly chains: Chain[];
  private readonly providerMap: Map<number, ethers.providers.JsonRpcProvider>;
  constructor(chains: Chain[], providerMap: Map<number, ethers.providers.JsonRpcProvider>) {
    this.chains = chains;
    this.providerMap = providerMap;
  }

  async GetAllByAddress(address: string, chainID?: number) {
    if(!address) {
     throw new Error("Address need to passed to fetch transactions");
    }
    let params = `address=${address}`;

    if(chainID) {
      params += `&chainID=${chainID}`;
    }

    
    const requestURL = `${import.meta.env.VITE_RELAYER_URL}events?${params}`;
    
    const { data } = await axios.get(requestURL);

    const txs: BridgeTransaction[] = data.map(tx => {
      ethersTx: ethers.Transaction;
      receipt?: ethers.providers.TransactionReceipt;
      status: MessageStatus;
      signal?: string;
      message?: Message;
      interval?: NodeJS.Timer;
      amountInWei?: BigNumber;
      symbol?: string;
      fromChainId: number;
      toChainId: number;
      return {
        ethersTx: {
          hash: tx.Raw.transactionHash,
          to: tx.Message.To,
          from: tx.Message.Owner,
          data: tx.Raw.data,
          value: tx.Message.CallValue,
          chainId: number;

          r?: string;
          s?: string;
          v?: number;

          // Typed-Transaction features
          type?: number | null;

          // EIP-2930; Type 1 & EIP-1559; Type 2
          accessList?: AccessList;

          // EIP-1559; Type 2
          maxPriorityFeePerGas?: BigNumber;
          maxFeePerGas?: BigNumber;
        }
      }
    })

    const bridgeTxs: BridgeTransaction[] = [];

    await Promise.all(
      (txs || []).map(async (tx) => {
        if (tx.Message.Owner.toLowerCase() !== address.toLowerCase()) return;

        const destChainId = tx.Message.DestChainId;
        const destProvider = this.providerMap.get(destChainId);

        const srcProvider = this.providerMap.get(tx.Message.SrcChainId);

        const receipt = await srcProvider.getTransactionReceipt(
          tx.Raw.transactionHash
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

        const signal = event.args.signal;

        const messageStatus: number = await destContract.getMessageStatus(
          signal
        );

        let amountInWei: BigNumber;
        let symbol: string;
        if (event.args.message.data !== "0x") {
          const tokenVaultContract = new Contract(
            get(chainIdToTokenVaultAddress).get(tx.fromChainId),
            TokenVault,
            srcProvider
          );
          const erc20Events = await tokenVaultContract.queryFilter(
            "ERC20Sent",
            receipt.blockNumber,
            receipt.blockNumber
          );

          const erc20Event = erc20Events.find(
            (e) => e.args.signal.toLowerCase() === signal.toLowerCase()
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
          signal: event.args.signal,
          ethersTx: tx.ethersTx,
          status: messageStatus,
          amountInWei: amountInWei,
          symbol: symbol,
          fromChainId: tx.fromChainId,
          toChainId: tx.toChainId,
        };

        bridgeTxs.push(bridgeTx);
      })
    );

    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return bridgeTxs;
  }

}

export default RelayerAPIService;