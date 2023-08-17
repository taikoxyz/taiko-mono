import type { Address, Hash } from '@wagmi/core';
import { readContract } from '@wagmi/core';
import axios from 'axios';
import { Buffer } from 'buffer';

import { bridgeABI } from '$abi';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import { chainContractsMap, isSupportedChain } from '../chain/chains';
import type {
  APIRequestParams,
  APIResponse,
  APIResponseTransaction,
  GetAllByAddressResponse,
  PaginationInfo,
  PaginationParams,
  RelayerBlockInfo,
} from './types';

const log = getLogger('RelayerAPIService');

export class RelayerAPIService {
  //Todo: duplicate code in BridgeTxService
  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    log(`Getting transaction receipt for ${hash} on chain ${chainId}`);
    try {
      const client = publicClient({ chainId });
      const receipt = await client.getTransactionReceipt({ hash });
      return receipt;
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

      const { bridgeAddress } = chainContractsMap[item.chainID]; // TODO: also handle unsupported chain
      const { DestChainId, SrcChainId } = Message;
      const { transactionHash, address } = Raw;

      // Check all conditions
      const isTransactionHashPresent = Boolean(transactionHash);
      const isAddressPresent = Boolean(address);
      const isUniqueHash = !uniqueHashes.has(transactionHash);
      const isCorrectBridgeAddress = address?.toLowerCase() === bridgeAddress?.toLowerCase();
      const areChainsSupported = isSupportedChain(BigInt(DestChainId)) && isSupportedChain(BigInt(SrcChainId));

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

  private static async _getBridgeMessageStatus(msgHash: Hash, chainId: number) {
    const { bridgeAddress } = chainContractsMap[Number(chainId)];
    const result = await readContract({
      address: bridgeAddress,
      abi: bridgeABI,
      chainId: Number(chainId),
      functionName: 'getMessageStatus',
      args: [msgHash],
    });
    return result as MessageStatus;
  }

  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    log('relayer service instantiated');
    // There is a chance that by accident the env var
    // does (or does not) have trailing slash for
    // this baseURL. Normalize it, preventing errors
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async getTransactionsFromAPI(params: APIRequestParams): Promise<APIResponse> {
    const requestURL = `${this.baseUrl}/events`;

    try {
      log('Fetching events from API with params', params);

      const response = await axios.get<APIResponse>(requestURL, {
        params,
        timeout: 5000, // todo: discuss and move to config
      });

      // response.data.items.push(...mockedData);
      if (response.status >= 400) throw response;

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
      let data: string = tx.data.Message.Data;
      if (data === '') {
        data = '0x';
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
        message: {
          id: tx.data.Message.Id,
          to: tx.data.Message.To,
          data: tx.data.Message.Data,
          memo: tx.data.Message.Memo,
          owner: tx.data.Message.Owner,
          sender: tx.data.Message.Sender,
          gasLimit: BigInt(tx.data.Message.GasLimit),
          callValue: BigInt(tx.data.Message.CallValue),
          srcChainId: BigInt(tx.data.Message.SrcChainId),
          destChainId: BigInt(tx.data.Message.DestChainId),
          depositValue: BigInt(tx.data.Message.DepositValue),
          processingFee: BigInt(tx.data.Message.ProcessingFee),
          refundAddress: tx.data.Message.RefundAddress,
        },
      } as BridgeTransaction;

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
      if (!receipt) return;

      bridgeTx.receipt = receipt;

      if (!msgHash) return; //todo: handle this case

      const status = await RelayerAPIService._getBridgeMessageStatus(msgHash, Number(destChainId));

      // Update the status
      bridgeTx.status = status;

      bridgeTx.tokenType = _checkType(bridgeTx);

      return bridgeTx;
    });

    const bridgeTxs: BridgeTransaction[] = (await Promise.all(txsPromises)).filter((tx): tx is BridgeTransaction =>
      Boolean(tx),
    ); // Removes undefined values

    // Spreading to preserve original txs in case of array mutation
    log('Enhanced transactions', [...bridgeTxs]);

    // We want to show the latest transactions first
    bridgeTxs.reverse();

    // Place new transactions at the top of the list
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.NEW ? -1 : 1));

    return { txs: bridgeTxs, paginationInfo };
  }

  async getBlockInfo(): Promise<Map<number, RelayerBlockInfo>> {
    const requestURL = `${this.baseUrl}/blockInfo`;

    // TODO: why to use a Map here?
    const blockInfoMap: Map<number, RelayerBlockInfo> = new Map();

    try {
      const response = await axios.get<{ data: RelayerBlockInfo[] }>(requestURL);

      if (response.status >= 400) throw response;

      const { data } = response;

      if (data?.data.length > 0) {
        data.data.forEach((blockInfo: RelayerBlockInfo) => blockInfoMap.set(blockInfo.chainID, blockInfo));
      }
    } catch (error) {
      console.error(error);
      throw new Error('failed to fetch block info', { cause: error });
    }

    return blockInfoMap;
  }
}

function _checkType(bridgeTx: BridgeTransaction): TokenType {
  const to = bridgeTx.message?.to;
  switch (to) {
    case chainContractsMap[Number(bridgeTx.srcChainId)].tokenVaultAddress:
      return TokenType.ERC20;
    case chainContractsMap[Number(bridgeTx.srcChainId)].erc721VaultAddress:
      return TokenType.ERC721;
    case chainContractsMap[Number(bridgeTx.srcChainId)].erc1155VaultAddress:
      return TokenType.ERC1155;
    default:
      return TokenType.ETH;
  }
}
