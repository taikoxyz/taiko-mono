import { getTransactionReceipt, readContract } from '@wagmi/core';
import axios from 'axios';
import { Buffer } from 'buffer';
import {
  type Address,
  decodeAbiParameters,
  decodeEventLog,
  decodeFunctionData,
  getAddress,
  type Hash,
  type Hex,
  numberToHex,
  type TransactionReceipt,
} from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { apiService } from '$config';
import type { BridgeTransaction, Message, MessageStatus } from '$libs/bridge';
import { bridgeTxKey } from '$libs/bridge/bridgeTxIdentity';
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

const relayerMessageIntegerFields = ['Fee', 'Value', 'Id', 'SrcChainId', 'DestChainId', 'amount', 'fee'];
// Only a complete integer token is rewritten. The trailing guard matters: `amount` and
// `fee` can arrive as a decimal or in exponent form, and quoting just the leading digits
// of `1.5` produces `"1".5` - invalid JSON that takes the whole response down with it.
const relayerMessageIntegerPattern = new RegExp(
  `("(${relayerMessageIntegerFields.join('|')})"\\s*:\\s*)(\\d+)(?![\\d.eE])`,
  'g',
);
type DecodedBridgeMessage = Omit<Message, 'gasLimit'> & { gasLimit: bigint | number };
type BridgeTransactionAssetDetails = {
  amount: bigint;
  tokenType: TokenType;
  canonicalTokenAddress?: Address;
  symbol: string;
  decimals?: number;
};

const onMessageInvocationAbi = [
  {
    type: 'function',
    name: 'onMessageInvocation',
    inputs: [{ name: 'data', type: 'bytes' }],
    outputs: [],
    stateMutability: 'payable',
  },
] as const;

const erc20InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'decimals', type: 'uint8' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256' },
] as const;

const erc721InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256[]' },
] as const;

const erc1155InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256[]' },
  { type: 'uint256[]' },
] as const;

export function preserveMessageIntegerPrecision(rawResponse: string): string {
  return rawResponse.replace(relayerMessageIntegerPattern, '$1"$3"');
}

export function parseRelayerApiResponse(rawResponse: string): APIResponse {
  return JSON.parse(preserveMessageIntegerPrecision(rawResponse));
}

export function parseApiBigInt(value: unknown): bigint {
  if (typeof value === 'bigint' || typeof value === 'string') {
    return BigInt(value);
  }
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) {
      throw new TypeError('Unsafe integer value from relayer API');
    }
    return BigInt(value);
  }
  throw new TypeError('Invalid integer value from relayer API');
}

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

  /**
   * @dev Drops rows the relayer repeated and rows for routes this UI does not serve.
   *
   *      Keyed by message, not by transaction. One transaction can emit several
   *      MessageSent events - a batching wallet, a contract that bridges twice - and each
   *      is a separately claimable row. Keying on the transaction hash dropped every one
   *      after the first here, before the message-level dedupe downstream could see them.
   *
   * @param items The rows one relayer page returned
   * @return filtered_ The rows worth transforming
   */
  private static _filterDuplicateAndWrongBridge(items: APIResponseTransaction[]): APIResponseTransaction[] {
    const uniqueMessages = new Set<string>();
    const filteredItems: APIResponseTransaction[] = [];
    for (const item of items) {
      const { Message, Raw } = item.data || {};

      // If no data is present, we skip this item
      if (!Message || !Raw) {
        continue;
      }

      const { DestChainId: destChainId, SrcChainId: srcChainId } = Message;
      // The relayer can return rows for routes this UI is not configured for. Index defensively so a
      // single unknown pair cannot throw and take the whole transaction list down with it.
      const bridgeAddress = routingContractsMap[Number(srcChainId)]?.[Number(destChainId)]?.bridgeAddress;
      const { transactionHash, address } = Raw;
      // The message hash when the relayer gave us one, the transaction hash otherwise
      const identity = bridgeTxKey({ msgHash: item.msgHash, srcTxHash: transactionHash });

      // Check all conditions
      const isTransactionHashPresent = Boolean(transactionHash);
      const isAddressPresent = Boolean(address);
      const isUniqueHash = !uniqueMessages.has(identity);
      const isCorrectBridgeAddress = address?.toLowerCase() === bridgeAddress?.toLowerCase();
      const areChainsSupported = isSupportedChain(Number(destChainId)) && isSupportedChain(Number(srcChainId));

      // All these conditions must be true
      const satisfiesAllConditions = [
        isTransactionHashPresent,
        isAddressPresent,
        isUniqueHash,
        isCorrectBridgeAddress,
        areChainsSupported,
      ].every(Boolean);

      // Invalid rows must not consume the identity and hide a later valid duplicate.
      if (satisfiesAllConditions) {
        uniqueMessages.add(identity);
        filteredItems.push(item);
      }
    }
    return filteredItems;
  }

  /**
   * Recovers the authoritative (msgHash, message) pair for a bridge transaction by decoding the
   * `MessageSent` logs of its source receipt. The relayer can pair a msgHash with a message body from a
   * different transaction; the pair inside a single log is consistent by construction, so the receipt wins.
   *
   * Returns undefined when the route is unknown or no log belongs to the user. Returns null when several
   * logs belong to the user and none can be tied back to the relayer row, because that row is unsafe to use.
   */
  private static _getBridgeMessageFromReceipt({
    receipt,
    srcChainId,
    destChainId,
    userAddress,
    currentMsgHash,
    currentMessageId,
  }: {
    receipt: TransactionReceipt;
    srcChainId: number;
    destChainId: number;
    userAddress: Address;
    currentMsgHash?: Hash;
    currentMessageId?: bigint;
  }) {
    const bridgeAddress = routingContractsMap[srcChainId]?.[destChainId]?.bridgeAddress;

    if (!bridgeAddress) return;

    const user = getAddress(userAddress);
    const candidates: { msgHash: Hash; message: Message }[] = [];

    for (const receiptLog of receipt.logs) {
      if (receiptLog.address.toLowerCase() !== bridgeAddress.toLowerCase()) continue;

      try {
        const decodedLog = decodeEventLog({
          abi: bridgeAbi,
          data: receiptLog.data,
          topics: receiptLog.topics,
        });

        if (decodedLog.eventName !== 'MessageSent') continue;

        const { msgHash, message } = decodedLog.args as {
          msgHash?: Hash;
          message?: DecodedBridgeMessage;
        };

        if (!msgHash || !message) continue;

        // `gasLimit` is uint32 today, which viem decodes as a number, so this guard is inert. It is kept so a
        // future widening of the ABI field surfaces as a skipped log rather than a silently truncated value.
        const gasLimit = Number(message.gasLimit);
        if (!Number.isSafeInteger(gasLimit)) {
          log('Decoded bridge message has unsafe gas limit', {
            gasLimit: message.gasLimit,
            txHash: receipt.transactionHash,
          });
          continue;
        }

        const normalizedMessage: Message = { ...message, gasLimit };
        const senderMatch = getAddress(normalizedMessage.srcOwner) === user;
        const receiverMatch = getAddress(normalizedMessage.destOwner) === user;

        if (senderMatch || receiverMatch) {
          candidates.push({ msgHash, message: normalizedMessage });
        }
      } catch (error) {
        log('Error decoding bridge receipt log', { error, txHash: receipt.transactionHash });
      }
    }

    const exactMatch = currentMsgHash
      ? candidates.find((candidate) => candidate.msgHash.toLowerCase() === currentMsgHash.toLowerCase())
      : undefined;
    if (exactMatch) return exactMatch;

    if (candidates.length === 1) return candidates[0];

    if (candidates.length > 1) {
      // The msgHash tied us to nothing, so fall back to the message id as a secondary key. It is only usable
      // when it singles out one log; anything else stays ambiguous.
      const idMatches =
        currentMessageId === undefined
          ? []
          : candidates.filter((candidate) => candidate.message.id === currentMessageId);

      if (idMatches.length === 1) return idMatches[0];

      console.warn('Multiple bridge receipt messages matched user without matching relayer msgHash', {
        txHash: receipt.transactionHash,
        currentMsgHash,
        currentMessageId,
      });
      return null;
    }
  }

  private static _getAssetDetailsFromMessage(message: Message): BridgeTransactionAssetDetails {
    const fallbackDetails: BridgeTransactionAssetDetails = {
      amount: message.value,
      tokenType: TokenType.ETH,
      canonicalTokenAddress: undefined,
      symbol: 'ETH',
      decimals: 18,
    };

    if (message.data === '0x') return fallbackDetails;

    const destinationRoute = routingContractsMap[Number(message.destChainId)]?.[Number(message.srcChainId)];
    if (!destinationRoute) return fallbackDetails;

    try {
      const decodedInvocation = decodeFunctionData({
        abi: onMessageInvocationAbi,
        data: message.data,
      });
      const invocationData = decodedInvocation.args[0];

      if (
        destinationRoute.erc20VaultAddress &&
        message.to.toLowerCase() === destinationRoute.erc20VaultAddress.toLowerCase()
      ) {
        const [canonicalToken, , , amount] = decodeAbiParameters(erc20InvocationParameters, invocationData);
        return {
          amount,
          tokenType: TokenType.ERC20,
          canonicalTokenAddress: canonicalToken.addr,
          symbol: canonicalToken.symbol,
          decimals: canonicalToken.decimals,
        };
      }

      if (
        destinationRoute.erc721VaultAddress &&
        message.to.toLowerCase() === destinationRoute.erc721VaultAddress.toLowerCase()
      ) {
        const [canonicalToken] = decodeAbiParameters(erc721InvocationParameters, invocationData);
        return {
          amount: 1n,
          tokenType: TokenType.ERC721,
          canonicalTokenAddress: canonicalToken.addr,
          symbol: canonicalToken.symbol,
          decimals: undefined,
        };
      }

      if (
        destinationRoute.erc1155VaultAddress &&
        message.to.toLowerCase() === destinationRoute.erc1155VaultAddress.toLowerCase()
      ) {
        const [canonicalToken, , , , amounts] = decodeAbiParameters(erc1155InvocationParameters, invocationData);
        return {
          amount: amounts.reduce((total, amount) => total + amount, 0n),
          tokenType: TokenType.ERC1155,
          canonicalTokenAddress: canonicalToken.addr,
          symbol: canonicalToken.symbol,
          decimals: undefined,
        };
      }
    } catch (error) {
      log('Error decoding bridge message asset details', { error, messageId: message.id });
    }

    return fallbackDetails;
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
    const bridgeAddress = routingContractsMap[Number(destChainId)]?.[Number(srcChainId)]?.bridgeAddress;

    if (!bridgeAddress) {
      // The caller drops the transaction when this returns undefined, so warn rather than debug-log: a route
      // that silently disappears from the config would otherwise erase transactions with no trace.
      console.warn('No bridge route configured for message status', { msgHash, srcChainId, destChainId });
      return;
    }

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

      const response = await axios.get<APIResponse | string>(requestURL, {
        params,
        timeout: apiService.timeout,
        transformResponse: [(data) => data],
      });

      if (!response || response.status >= 400) throw response;

      const data = typeof response.data === 'string' ? parseRelayerApiResponse(response.data) : response.data;

      log('Events form API', data);

      return data;
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
    chainId?: number,
  ): Promise<GetAllByAddressResponse> {
    let params;
    if (chainId) {
      params = {
        address,
        chainID: chainId,
        event: 'MessageSent',
        ...paginationParams,
      };
    } else {
      params = {
        address,
        event: 'MessageSent',
        ...paginationParams,
      };
    }

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

    if (!apiTxs.items || apiTxs.items.length === 0) {
      return { txs: [], paginationInfo };
    }

    const items = RelayerAPIService._filterDuplicateAndWrongBridge(apiTxs.items);

    const txs: BridgeTransaction[] = items
      .map((tx: APIResponseTransaction) => {
        try {
          return RelayerAPIService._transformTransaction(tx);
        } catch (error) {
          log('Skipping malformed relayer transaction', { error, tx });
          return null;
        }
      })
      .filter((tx): tx is BridgeTransaction => tx !== null);

    const txsPromises = txs.map(async (bridgeTx) => {
      if (!bridgeTx) return;
      try {
        return await RelayerAPIService._enhanceTransaction(bridgeTx, address);
      } catch (error) {
        // One failing RPC read must not reject the surrounding Promise.all and wipe the list
        log('Skipping transaction that failed to enhance', { error, srcTxHash: bridgeTx.srcTxHash });
        return;
      }
    });

    const enhanced: BridgeTransaction[] = (await Promise.all(txsPromises)).filter((tx): tx is BridgeTransaction =>
      Boolean(tx),
    ); // Removes undefined values

    // A second dedupe, now that each row carries the message hash its receipt log proves.
    // Both are needed and neither subsumes the other: the filter above cannot tell a
    // relayer row whose msgHash is corrupt from a genuine second message, because the
    // corrupt hash is a hash like any other; enhancement resolves it to the log the
    // transaction actually emitted, and only then are the two rows visibly the same one.
    const seenMessages = new Set<string>();
    const bridgeTxs = enhanced.filter((bridgeTx) => {
      const identity = bridgeTxKey(bridgeTx);
      if (seenMessages.has(identity)) {
        log('Dropping a relayer row the receipt resolved onto an already-seen message', identity);
        return false;
      }
      seenMessages.add(identity);
      return true;
    });

    // Spreading to preserve original txs in case of array mutation
    log('Enhanced transactions', [...bridgeTxs]);

    return { txs: bridgeTxs, paginationInfo };
  }

  private static _transformTransaction(tx: APIResponseTransaction): BridgeTransaction {
    {
      let data: string | Hex = tx.data.Message.Data;
      if (data === '') {
        data = '0x' as Hex;
      } else if (data !== '0x') {
        const buffer = Buffer.from(data, 'base64');
        data = `0x${buffer.toString('hex')}`;
      }

      const tokenType: TokenType = _eventToTokenType(tx.eventType);

      const relayerFee = tx.fee ? parseApiBigInt(tx.fee) : undefined;
      const messageFee = parseApiBigInt(tx.data.Message.Fee);
      const messageValue = parseApiBigInt(tx.data.Message.Value);
      const messageId = parseApiBigInt(tx.data.Message.Id);
      const srcChainId = parseApiBigInt(tx.data.Message.SrcChainId);
      const destChainId = parseApiBigInt(tx.data.Message.DestChainId);

      const transformedTx = {
        status: tx.status,
        amount: BigInt(tx.amount),
        symbol: tx.canonicalTokenSymbol || 'ETH',
        // The relayer nils canonicalToken for ETH rows and the Go field is a plain uint8,
        // so every ETH transaction arrives as decimals 0. The correct 18 is otherwise only
        // applied later from the source-chain receipt, and that fetch is allowed to fail -
        // a row that keeps 0 renders one ETH as 1000000000000000000
        decimals: tokenType === TokenType.ETH ? 18 : tx.canonicalTokenDecimals,
        srcTxHash: tx.data.Raw.transactionHash,
        destTxHash: tx.processedTxHash,
        from: getAddress(tx.messageOwner),
        srcChainId,
        destChainId,
        msgHash: tx.msgHash,
        tokenType: tokenType,
        blockNumber: tx.data.Raw.blockNumber,
        canonicalTokenAddress: tx.canonicalTokenAddress,
        processingFee: messageFee,
        claimedBy: tx.claimedBy ? getAddress(tx.claimedBy) : undefined,
        // A relayer that has not claimed the message reports zero here, so zero means "no
        // relayer has been paid yet" rather than "the fee was zero" - undefined says that
        // without inviting a reader to treat it as a settled amount. Both consumers render
        // it as `formatEther(fee ?? 0n)`, so nothing downstream tells the two apart.
        fee: relayerFee && relayerFee !== BigInt(0) ? relayerFee : undefined,
        message: {
          id: messageId,
          to: getAddress(tx.data.Message.To),
          destOwner: getAddress(tx.data.Message.DestOwner),
          data: data as Hex,
          srcOwner: getAddress(tx.data.Message.SrcOwner),
          from: getAddress(tx.data.Message.From),
          gasLimit: tx.data.Message.GasLimit,
          value: messageValue,
          srcChainId,
          destChainId,
          fee: messageFee,
        },
      } satisfies BridgeTransaction;

      return transformedTx;
    }
  }

  private static async _enhanceTransaction(
    bridgeTx: BridgeTransaction,
    address: Address,
  ): Promise<BridgeTransaction | undefined> {
    {
      const senderMatch = getAddress(bridgeTx.from) === getAddress(address);
      const receiverMatch = bridgeTx.message && getAddress(bridgeTx.message.destOwner) === getAddress(address);

      if (!senderMatch && !receiverMatch) return;

      const { destChainId, srcChainId, srcTxHash } = bridgeTx;

      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      const receipt = await RelayerAPIService._getTransactionReceipt(Number(srcChainId), srcTxHash);

      // TODO: do we want to show these transactions?
      if (!receipt || receipt === null) {
        log('Transaction not mined yet', { srcTxHash, srcChainId });
      }

      bridgeTx.receipt = receipt as TransactionReceipt;

      if (receipt) {
        bridgeTx.blockNumber = numberToHex(receipt.blockNumber);

        const receiptMessage = RelayerAPIService._getBridgeMessageFromReceipt({
          receipt,
          srcChainId: Number(srcChainId),
          destChainId: Number(destChainId),
          userAddress: address,
          currentMsgHash: bridgeTx.msgHash,
          currentMessageId: bridgeTx.message?.id,
        });

        // A successful receipt with several user messages disproves the relayer pair without identifying a
        // safe replacement. Do not expose that unrelated pair to status checks or claim actions.
        if (receiptMessage === null) return;

        if (receiptMessage) {
          const msgHashChanged = bridgeTx.msgHash?.toLowerCase() !== receiptMessage.msgHash.toLowerCase();

          if (msgHashChanged) {
            // This is the signal that the relayer paired a msgHash with a foreign message body. Warn rather
            // than debug-log so the rate of this corruption is observable in production.
            console.warn('Relayer transaction data differs from receipt log', {
              srcTxHash,
              relayerMsgHash: bridgeTx.msgHash,
              receiptMsgHash: receiptMessage.msgHash,
            });
          }

          bridgeTx.msgHash = receiptMessage.msgHash;
          bridgeTx.message = receiptMessage.message;
          bridgeTx.processingFee = receiptMessage.message.fee;
          bridgeTx.srcChainId = receiptMessage.message.srcChainId;
          bridgeTx.destChainId = receiptMessage.message.destChainId;

          Object.assign(bridgeTx, RelayerAPIService._getAssetDetailsFromMessage(receiptMessage.message));

          if (msgHashChanged) {
            // The row we started from described a different message, so everything keyed to the old msgHash
            // is about that other message and cannot be trusted here. Drop it and let the on-chain status
            // read below repopulate what matters.
            bridgeTx.destTxHash = undefined;
            bridgeTx.claimedBy = undefined;
            bridgeTx.fee = undefined;
          }
        }
      }

      if (!bridgeTx.msgHash) return; //todo: handle this case

      const msgStatus = await RelayerAPIService._getBridgeMessageStatus({
        msgHash: bridgeTx.msgHash,
        srcChainId: Number(bridgeTx.srcChainId),
        destChainId: Number(bridgeTx.destChainId),
      });

      if (msgStatus === undefined) return;

      // Update the status
      bridgeTx.msgStatus = msgStatus;
      bridgeTx.status = msgStatus;

      return bridgeTx;
    }
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
