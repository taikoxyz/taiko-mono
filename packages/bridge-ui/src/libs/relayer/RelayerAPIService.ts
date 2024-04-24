import { getTransactionReceipt, readContract } from '@wagmi/core';
import axios from 'axios';
import { Buffer } from 'buffer';
import type { Address, Hash, Hex, TransactionReceipt } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { apiService } from '$config';
import type { BridgeTransaction, MessageStatus } from '$libs/bridge';
import { isSupportedChain } from '$libs/chain';
import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import {
  type APIRequestParams,
  type APIResponse,
  type APIResponseTransaction,
  type Fee,
  type FeeType,
  type GetAllByAddressResponse,
  type PaginationInfo,
  type PaginationParams,
  type ProcessingFeeApiResponse,
  type RelayerBlockInfo,
  RelayerEventType,
} from './types';

const log = getLogger('RelayerAPIService');

export class RelayerAPIService {
  constructor(baseUrl: string) {
    log('relayer service instantiated');
    // There is a chance that by accident the env var
    // does (or does not) have trailing slash for
    // this baseURL. Normalize it, preventing errors
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  //Todo: duplicate code in BridgeTxService
  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    try {
      return await getTransactionReceipt(config, { chainId, hash });
    } catch (error) {
      log(`Error getting transaction receipt for ${hash}: ${error}`);
      return null;
    }
  }

  private static _filterDuplicateAndWrongBridge(items: APIResponseTransaction[]): APIResponseTransaction[] {
    const uniqueHashes = new Set<string>();
    const filteredItems: APIResponseTransaction[] = [];
    for (const item of items) {
      const { Message, Raw } = item.data || {};

      // If no data is present, we skip this item
      if (!Message || !Raw) {
        continue;
      }

      const { DestChainId: destChainId, SrcChainId: srcChainId } = Message;
      const { bridgeAddress } = routingContractsMap[Number(srcChainId)][Number(destChainId)];
      const { transactionHash, address } = Raw;

      // Check all conditions
      const isTransactionHashPresent = Boolean(transactionHash);
      const isAddressPresent = Boolean(address);
      const isUniqueHash = !uniqueHashes.has(transactionHash);
      const isCorrectBridgeAddress = address?.toLowerCase() === bridgeAddress?.toLowerCase();
      const areChainsSupported = isSupportedChain(Number(destChainId)) && isSupportedChain(Number(srcChainId));

      // If the transaction hash is unique, add it to the set for future checks
      if (isUniqueHash) uniqueHashes.add(transactionHash);

      // All these conditions must be true
      const satisfiesAllConditions = [
        isTransactionHashPresent,
        isAddressPresent,
        isUniqueHash,
        isCorrectBridgeAddress,
        areChainsSupported,
      ].every(Boolean);

      // If all conditions are satisfied, add the item to the filtered list
      if (satisfiesAllConditions) filteredItems.push(item);
    }
    return filteredItems;
  }

  private static async _getBridgeMessageStatus({
    msgHash,
    srcChainId,
    destChainId,
  }: {
    msgHash: Hash;
    srcChainId: number;
    destChainId: number;
  }) {
    const { bridgeAddress } = routingContractsMap[Number(destChainId)][Number(srcChainId)];

    const result = await readContract(config, {
      address: bridgeAddress,
      abi: bridgeAbi,
      chainId: Number(destChainId),
      functionName: 'messageStatus',
      args: [msgHash],
    });
    return result as MessageStatus;
  }

  private readonly baseUrl: string;

  async getTransactionsFromAPI(params: APIRequestParams): Promise<APIResponse> {
    const requestURL = `${this.baseUrl}/events`;

    try {
      log('Fetching events from API with params', params);

      const response = await axios.get<APIResponse>(requestURL, {
        params,
        timeout: apiService.timeout,
      });

      if (!response || response.status >= 400) throw response;

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

    const items = RelayerAPIService._filterDuplicateAndWrongBridge(apiTxs.items);
    const txs: BridgeTransaction[] = items.map((tx: APIResponseTransaction) => {
      let data: string | Hex = tx.data.Message.Data;
      if (data === '') {
        data = '' as Hex;
      } else if (data !== '0x') {
        const buffer = Buffer.from(data, 'base64');
        data = `0x${buffer.toString('hex')}`;
      }

      const transformedTx = {
        status: tx.status,
        amount: BigInt(tx.amount),
        symbol: tx.canonicalTokenSymbol || 'ETH',
        decimals: tx.canonicalTokenDecimals,
        hash: tx.data.Raw.transactionHash,
        from: tx.messageOwner,
        srcChainId: tx.data.Message.SrcChainId,
        destChainId: tx.data.Message.DestChainId,
        msgHash: tx.msgHash,
        tokenType: _eventToTokenType(tx.eventType),
        blockNumber: tx.data.Raw.blockNumber,
        message: {
          id: tx.data.Message.Id,
          to: tx.data.Message.To,
          destOwner: tx.data.Message.DestOwner,
          data: data as Hex,
          srcOwner: tx.data.Message.SrcOwner,
          from: tx.data.Message.From,
          gasLimit: Number(tx.data.Message.GasLimit),
          value: BigInt(tx.data.Message.Value),
          srcChainId: BigInt(tx.data.Message.SrcChainId),
          destChainId: BigInt(tx.data.Message.DestChainId),
          fee: BigInt(tx.data.Message.Fee),
        },
      } satisfies BridgeTransaction;

      return transformedTx;
    });

    const txsPromises = txs.map(async (bridgeTx) => {
      if (!bridgeTx) return;
      if (bridgeTx.from.toLowerCase() !== address.toLowerCase()) return;
      const { destChainId, srcChainId, hash, msgHash } = bridgeTx;

      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      const receipt = await RelayerAPIService._getTransactionReceipt(Number(srcChainId), hash);

      // TODO: do we want to show these transactions?
      if (!receipt || receipt === null) {
        log('Transaction not mined yet', { hash, srcChainId });
      }

      bridgeTx.receipt = receipt as TransactionReceipt;

      if (!msgHash) return; //todo: handle this case

      const msgStatus = await RelayerAPIService._getBridgeMessageStatus({
        msgHash,
        srcChainId: Number(srcChainId),
        destChainId: Number(destChainId),
      });

      // Update the status
      bridgeTx.msgStatus = msgStatus;
      return bridgeTx;
    });

    const bridgeTxs: BridgeTransaction[] = (await Promise.all(txsPromises)).filter((tx): tx is BridgeTransaction =>
      Boolean(tx),
    ); // Removes undefined values

    // Spreading to preserve original txs in case of array mutation
    log('Enhanced transactions', [...bridgeTxs]);

    return { txs: bridgeTxs, paginationInfo };
  }

  async getBlockInfo(): Promise<Record<number, RelayerBlockInfo>> {
    const requestURL = `${this.baseUrl}/blockInfo`;
    const blockInfoRecord: Record<number, RelayerBlockInfo> = {};

    try {
      const response = await axios.get<{ data: RelayerBlockInfo[] }>(requestURL);

      if (response.status >= 400) throw response;

      const { data } = response;

      if (data?.data.length > 0) {
        data.data.forEach((blockInfo: RelayerBlockInfo) => (blockInfoRecord[blockInfo.chainID] = blockInfo));
      }
    } catch (error) {
      console.error(error);
      throw new Error('Failed to fetch block info', { cause: error });
    }

    return blockInfoRecord;
  }

  async getSpecificBlockInfo({
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    srcChainId,
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    destChainId,
  }: {
    srcChainId: number;
    destChainId: number;
  }): Promise<Record<number, RelayerBlockInfo>> {
    throw new Error('Not implemented');
  }

  async recommendedProcessingFees({
    typeFilter,
    destChainIDFilter,
  }: {
    typeFilter?: FeeType;
    destChainIDFilter?: number;
  }): Promise<Fee[]> {
    const requestURL = `${this.baseUrl}/recommendedProcessingFees`;

    try {
      const response = await axios.get<ProcessingFeeApiResponse>(requestURL);

      if (response.status >= 400) throw new Error('HTTP error', { cause: response });

      let { fees } = response.data;

      if (typeFilter) {
        fees = fees.filter((fee) => fee.type === typeFilter);
      }

      if (destChainIDFilter !== undefined) {
        fees = fees.filter((fee) => fee.destChainID === destChainIDFilter);
      }

      return fees;
    } catch (error) {
      console.error(error);
      throw new Error('Failed to fetch recommended processing fees', {
        cause: error instanceof Error ? error : undefined,
      });
    }
  }
}

const _eventToTokenType = (eventType: RelayerEventType): TokenType => {
  switch (eventType) {
    case RelayerEventType.ERC20:
      return TokenType.ERC20;
    case RelayerEventType.ERC721:
      return TokenType.ERC721;
    case RelayerEventType.ERC1155:
      return TokenType.ERC1155;
    default:
      return TokenType.ETH;
  }
};
