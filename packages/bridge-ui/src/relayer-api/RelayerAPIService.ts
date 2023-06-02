import type { Address } from '@wagmi/core';
import axios from 'axios';
import { BigNumber, Contract, ethers } from 'ethers';

import { chains } from '../chain/chains';
import { bridgeABI, erc20ABI, tokenVaultABI } from '../constants/abi';
import { MessageStatus } from '../domain/message';
import type { RecordProviders } from '../domain/provider';
import type {
  APIRequestParams,
  APIResponse,
  APIResponseTransaction,
  GetAllByAddressResponse,
  PaginationInfo,
  PaginationParams,
  RelayerAPI,
  RelayerBlockInfo,
} from '../domain/relayerApi';
import type { BridgeTransaction } from '../domain/transaction';
import { getLogger } from '../utils/logger';
import { tokenVaults } from '../vault/tokenVaults';

const log = getLogger('RelayerAPIService');

export class RelayerAPIService implements RelayerAPI {
  private static _filterDuplicateHashes(items: APIResponseTransaction[]) {
    const uniqueHashes = new Set<string>();
    const filteredItems: APIResponseTransaction[] = [];

    for (const item of items) {
      if (!uniqueHashes.has(item.data.Raw.transactionHash)) {
        uniqueHashes.add(item.data.Raw.transactionHash);
        filteredItems.push(item);
      }
    }

    return filteredItems;
  }

  private static _getBridgeMessageStatus(
    bridgeAddress: Address,
    bridgeAbi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
    msgHash: string,
  ) {
    const bridgeContract: Contract = new Contract(
      bridgeAddress,
      bridgeAbi,
      provider,
    );

    return bridgeContract.getMessageStatus(msgHash);
  }

  private static async _getTokenVaultERC20Event(
    tokenVaultAddress: Address,
    tokenVaultAbi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
    msgHash: string,
    blockNumber: number,
  ) {
    const tokenVaultContract = new Contract(
      tokenVaultAddress,
      tokenVaultAbi,
      provider,
    );

    const filter = tokenVaultContract.filters.ERC20Sent(msgHash);

    const events = await tokenVaultContract.queryFilter(
      filter,
      blockNumber,
      blockNumber,
    );

    return events.find(
      ({ args }) => args.msgHash.toLowerCase() === msgHash.toLowerCase(),
    );
  }

  private static async _getERC20SymbolAndAmount(
    erc20Event: ethers.Event,
    erc20Abi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
  ): Promise<[string, BigNumber]> {
    const { token, amount } = erc20Event.args;
    const erc20Contract = new Contract(token, erc20Abi, provider);

    const symbol: string = await erc20Contract.symbol();
    const amountInWei: BigNumber = BigNumber.from(amount);

    return [symbol, amountInWei];
  }

  private readonly providers: RecordProviders;
  private readonly baseUrl: string;

  constructor(baseUrl: string, providers: RecordProviders) {
    this.providers = providers;

    // There is a chance that by accident the env var
    // does (or does not) have trailing slash for
    // this baseURL. Normalize it, preventing errors
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async getTransactionsFromAPI(params: APIRequestParams): Promise<APIResponse> {
    const requestURL = `${this.baseUrl}/events`;

    try {
      log('Fetching events from API with params', params);

      const response = await axios.get<APIResponse>(requestURL, { params });

      // TODO: status >= 400 ?

      log('Events form API', response.data);

      return response.data;
    } catch (error) {
      console.error(error);
      throw new Error('could not fetch transactions from API', {
        cause: error,
      });
    }
  }

  async getAllBridgeTransactionByAddress(
    address: Address,
    paginationParams: PaginationParams,
    chainID?: number,
  ): Promise<GetAllByAddressResponse> {
    const params = {
      address,
      chainID,
      event: 'MessageSent',
      ...paginationParams,
    };

    const apiTxs: APIResponse = await this.getTransactionsFromAPI(params);

    const { page, size, total, total_pages, first, last, max_page } = apiTxs;

    // TODO: we cannot rely on these values, because the API might return duplicates
    //       and we need to filter them out in the Frontend side. We should fix this
    //       in the API side.
    const paginationInfo: PaginationInfo = {
      page,
      size,
      total,
      total_pages,
      first,
      last,
      max_page,
    };

    if (apiTxs.items?.length === 0) {
      return { txs: [], paginationInfo };
    }

    apiTxs.items = RelayerAPIService._filterDuplicateHashes(apiTxs.items);

    const txs = apiTxs.items.map((tx: APIResponseTransaction) => {
      let data = tx.data.Message.Data;
      if (data === '') {
        data = '0x'; // ethers does not allow "" for empty bytes value
      } else if (data !== '0x') {
        const buffer = Buffer.from(data, 'base64');
        data = `0x${buffer.toString('hex')}`;
      }

      return {
        status: tx.status,
        amountInWei: BigNumber.from(tx.amount),
        symbol: tx.canonicalTokenSymbol,
        hash: tx.data.Raw.transactionHash,
        from: tx.messageOwner,
        srcChainId: tx.data.Message.SrcChainId,
        destChainId: tx.data.Message.DestChainId,
        msgHash: tx.msgHash,
        canonicalTokenAddress: tx.canonicalTokenAddress,
        canonicalTokenSymbol: tx.canonicalTokenSymbol,
        canonicalTokenName: tx.canonicalTokenName,
        canonicalTokenDecimals: tx.canonicalTokenDecimals,
        message: {
          id: tx.data.Message.Id,
          to: tx.data.Message.To,
          data,
          memo: tx.data.Message.Memo,
          owner: tx.data.Message.Owner,
          sender: tx.data.Message.Sender,
          gasLimit: BigNumber.from(tx.data.Message.GasLimit.toString()),
          callValue: BigNumber.from(tx.data.Message.CallValue.toString()),
          srcChainId: tx.data.Message.SrcChainId,
          destChainId: tx.data.Message.DestChainId,
          depositValue: BigNumber.from(
            `${tx.data.Message.DepositValue.toString()}`,
          ),
          processingFee: BigNumber.from(
            `${tx.data.Message.ProcessingFee.toString()}`,
          ),
          refundAddress: tx.data.Message.RefundAddress,
        },
      };
    });

    const txsPromises = txs.map(async (tx) => {
      if (tx.from.toLowerCase() !== address.toLowerCase()) return;

      const bridgeTx: BridgeTransaction = {
        message: tx.message,
        msgHash: tx.msgHash,
        status: tx.status,
        amountInWei: tx.amountInWei,
        srcChainId: tx.srcChainId,
        destChainId: tx.destChainId,
        hash: tx.hash,
        from: tx.from,
      };

      const { destChainId, srcChainId, hash, msgHash } = bridgeTx;

      const destProvider = this.providers[destChainId];
      const srcProvider = this.providers[srcChainId];

      // Ignore transactions from chains not supported by the bridge
      if (!srcProvider) return;

      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      const receipt = await srcProvider.getTransactionReceipt(hash);

      // TODO: do we want to show these transactions?
      //       If not, we simply return undefined and it'll
      //       be filtered out later.
      // if (!receipt) {
      //   return bridgeTx;
      // }
      if (!receipt) return;

      bridgeTx.receipt = receipt;

      const destBridgeAddress = chains[destChainId].bridgeAddress;

      const status = await RelayerAPIService._getBridgeMessageStatus(
        destBridgeAddress,
        bridgeABI,
        destProvider,
        msgHash,
      );

      bridgeTx.status = status;

      let amountInWei: BigNumber = tx.amountInWei;
      let symbol: string;

      if (tx.canonicalTokenAddress !== ethers.constants.AddressZero) {
        // We're dealing with an ERC20 transfer.
        // Let's get the symbol and amount from the TokenVault contract.

        const srcTokenVaultAddress = tokenVaults[srcChainId];

        const erc20Event = await RelayerAPIService._getTokenVaultERC20Event(
          srcTokenVaultAddress,
          tokenVaultABI,
          srcProvider,
          msgHash,
          receipt.blockNumber,
        );

        // if (!erc20Event) {
        //   return bridgeTx;
        // }
        if (!erc20Event) return;

        [symbol, amountInWei] =
          await RelayerAPIService._getERC20SymbolAndAmount(
            erc20Event,
            erc20ABI,
            srcProvider,
          );
      }

      bridgeTx.amountInWei = amountInWei;
      bridgeTx.symbol = symbol;

      return bridgeTx;
    });

    const bridgeTxs: BridgeTransaction[] = (
      await Promise.all(txsPromises)
    ).filter((tx) => Boolean(tx)); // Removes undefined values

    // Spreading to preserve original txs in case of array mutation
    log('Enhanced transactions', [...bridgeTxs]);

    // We want to show the latest transactions first
    bridgeTxs.reverse();

    // Place new transactions at the top of the list
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return { txs: bridgeTxs, paginationInfo };
  }

  async getBlockInfo(): Promise<Map<number, RelayerBlockInfo>> {
    const requestURL = `${this.baseUrl}/blockInfo`;

    // TODO: why to use a Map here?
    const blockInfoMap: Map<number, RelayerBlockInfo> = new Map();

    try {
      const { data } = await axios.get<{ data: RelayerBlockInfo[] }>(
        requestURL,
      );

      // TODO: status >= 400 ?

      if (data?.data.length > 0) {
        data.data.forEach((blockInfo) => {
          blockInfoMap.set(blockInfo.chainID, blockInfo);
        });
      }
    } catch (error) {
      console.error(error);
      throw new Error('failed to fetch block info', { cause: error });
    }

    return blockInfoMap;
  }
}
