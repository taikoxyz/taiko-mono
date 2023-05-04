import axios from 'axios';
import { BigNumber, Contract, ethers } from 'ethers';
import BridgeABI from '../constants/abi/Bridge.json';
import ERC20_ABI from '../constants/abi/ERC20.json';
import TokenVaultABI from '../constants/abi/TokenVault.json';
import { MessageStatus } from '../domain/message';

import type { BridgeTransaction } from '../domain/transactions';
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
import { chains } from '../chain/chains';
import { tokenVaults } from '../vault/tokenVaults';
import type { ChainID } from '../domain/chain';

export class RelayerAPIService implements RelayerAPI {
  private readonly providers: Record<
    ChainID,
    ethers.providers.StaticJsonRpcProvider
  >;
  private readonly baseUrl: string;

  constructor(
    baseUrl: string,
    providers: Record<ChainID, ethers.providers.StaticJsonRpcProvider>,
  ) {
    this.providers = providers;

    // There is a chance that by accident the env var
    // does (or does not) have trailing slash for
    // this baseURL. Normalize it, preventing errors
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async getTransactionsFromAPI(params: APIRequestParams): Promise<APIResponse> {
    const requestURL = `${this.baseUrl}/events`;

    const response = await axios.get<APIResponse>(requestURL, { params });

    return response.data;
  }

  async getAllBridgeTransactionByAddress(
    address: string,
    paginationParams: PaginationParams,
    chainID?: number,
  ): Promise<GetAllByAddressResponse> {
    if (!address) {
      throw new Error('Address need to passed to fetch transactions');
    }

    const params = {
      address,
      chainID,
      event: 'MessageSent',
      ...paginationParams,
    };

    const apiTxs: APIResponse = await this.getTransactionsFromAPI(params);

    const paginationInfo: PaginationInfo = {
      page: apiTxs.page,
      size: apiTxs.size,
      total: apiTxs.total,
      total_pages: apiTxs.total_pages,
      first: apiTxs.first,
      last: apiTxs.last,
      max_page: apiTxs.max_page,
    };

    if (apiTxs?.items?.length === 0) {
      return { txs: [], paginationInfo };
    }

    apiTxs.items.map((t, i) => {
      apiTxs.items.map((tx, j) => {
        if (
          tx.data.Raw.transactionHash === t.data.Raw.transactionHash &&
          i !== j
        ) {
          apiTxs.items = apiTxs.items.filter((_, index) => index !== j);
        }
      });
    });

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
        fromChainId: tx.data.Message.SrcChainId,
        toChainId: tx.data.Message.DestChainId,
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

    const bridgeTxs: BridgeTransaction[] = await Promise.all(
      (txs || []).map(async (tx) => {
        if (tx.from.toLowerCase() !== address.toLowerCase()) return;

        const destChainId = tx.toChainId;
        const destProvider = this.providers[destChainId];
        const srcProvider = this.providers[tx.fromChainId];
        const receipt = await srcProvider.getTransactionReceipt(tx.hash);

        if (!receipt) {
          return tx;
        }

        const destBridgeAddress = chains[destChainId].bridgeAddress;

        const destContract: Contract = new Contract(
          destBridgeAddress,
          BridgeABI,
          destProvider,
        );

        const msgHash = tx.msgHash;

        const messageStatus: number = await destContract.getMessageStatus(
          msgHash,
        );

        let amountInWei: BigNumber = tx.amountInWei;
        let symbol: string;
        if (tx.canonicalTokenAddress !== ethers.constants.AddressZero) {
          const tokenVaultContract = new Contract(
            tokenVaults[tx.fromChainId],
            TokenVaultABI,
            srcProvider,
          );
          const filter = tokenVaultContract.filters.ERC20Sent(msgHash);
          const erc20Events = await tokenVaultContract.queryFilter(
            filter,
            receipt.blockNumber,
            receipt.blockNumber,
          );

          const erc20Event = erc20Events.find(
            (e) => e.args.msgHash.toLowerCase() === msgHash.toLowerCase(),
          );
          if (!erc20Event) return;

          const erc20Contract = new Contract(
            erc20Event.args.token,
            ERC20_ABI,
            srcProvider,
          );
          symbol = await erc20Contract.symbol();
          amountInWei = BigNumber.from(erc20Event.args.amount);
        }

        const bridgeTx: BridgeTransaction = {
          message: tx.message,
          receipt: receipt,
          msgHash: tx.msgHash,
          status: messageStatus,
          amountInWei: amountInWei,
          symbol: symbol,
          fromChainId: tx.fromChainId,
          toChainId: tx.toChainId,
          hash: tx.hash,
          from: tx.from,
        };
        return bridgeTx;
      }),
    );

    bridgeTxs.reverse();
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));
    return { txs: bridgeTxs, paginationInfo };
  }

  async getBlockInfo(): Promise<Map<number, RelayerBlockInfo>> {
    const requestURL = `${this.baseUrl}/blockInfo`;
    const { data } = await axios.get(requestURL);
    const blockInfoMap: Map<number, RelayerBlockInfo> = new Map();
    if (data?.data.length > 0) {
      data.data.forEach((blockInfoByChain) => {
        blockInfoMap.set(blockInfoByChain.chainID, blockInfoByChain);
      });
    }

    return blockInfoMap;
  }
}
