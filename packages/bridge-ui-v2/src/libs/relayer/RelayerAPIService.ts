/* eslint-disable no-console */
import type { Address, Hash } from '@wagmi/core';
import { readContract } from '@wagmi/core';
import type { Abi } from 'abitype';
import axios from 'axios';

import { bridgeABI } from '$abi';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import { chainContractsMap, type ChainID, isSupportedChain } from '../chain/chains';
import type {
  APIRequestParams,
  APIResponse,
  APIResponseTransaction,
  GetAllByAddressResponse,
  PaginationInfo,
  PaginationParams,
  RelayerAPI,
  RelayerBlockInfo,
} from './relayerApi';

const log = getLogger('RelayerAPIService');

export class RelayerAPIService implements RelayerAPI {
  private static async _getTransactionReceipt(chainId: ChainID, hash: Hash) {
    const client = publicClient({ chainId: Number(chainId) });
    return client.getTransactionReceipt({ hash });
  }

  private static _filterDuplicateAndWrongBridge(items: APIResponseTransaction[]): APIResponseTransaction[] {
    const uniqueHashes = new Set<string>();
    const filteredItems: APIResponseTransaction[] = [];
    for (const item of items) {
      const { bridgeAddress } = chainContractsMap[item.chainID]; // todo:  also handle unsupported chain

      // Todo: fix
      // eslint-disable-next-line no-unsafe-optional-chaining
      const { DestChainId, SrcChainId } = item.data?.Message;
      // eslint-disable-next-line no-unsafe-optional-chaining
      const { transactionHash, address } = item.data?.Raw;
      const hasDuplicateHash = uniqueHashes.has(transactionHash);
      const wrongBridgeAddress = address?.toLowerCase() !== bridgeAddress?.toLowerCase();

      // Filter unsupported Chains
      const isSupported: boolean = isSupportedChain(BigInt(DestChainId)) && isSupportedChain(BigInt(SrcChainId));

      // Do not include tx if for whatever reason the properties transactionHash
      // and address are not present in the response
      const shouldIncludeTx = transactionHash && address && !hasDuplicateHash && !wrongBridgeAddress && isSupported;

      if (!hasDuplicateHash) uniqueHashes.add(transactionHash);
      if (shouldIncludeTx) filteredItems.push(item);
    }
    return filteredItems;
  }

  private static async _getBridgeMessageStatus(
    bridgeAddress: Address,
    bridgeAbi: Abi,
    chainId: ChainID,
    msgHash: string,
  ) {
    const result = await readContract({
      address: bridgeAddress,
      abi: bridgeAbi,
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
          srcChainId: tx.data.Message.SrcChainId,
          destChainId: tx.data.Message.DestChainId,
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
      const receipt = await RelayerAPIService._getTransactionReceipt(srcChainId, hash);

      // TODO: do we want to show these transactions?
      if (!receipt) return;

      bridgeTx.receipt = receipt;

      const { bridgeAddress: destBridgeAddress } = chainContractsMap[Number(destChainId)];

      if (!msgHash) return; //todo: handle this case

      const status: MessageStatus = await RelayerAPIService._getBridgeMessageStatus(
        destBridgeAddress,
        bridgeABI,
        destChainId,
        msgHash,
      );

      // Update the status
      bridgeTx.status = status;

      const type = checkType(bridgeTx);

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

function checkType(bridgeTx: BridgeTransaction): TokenType {
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
