import axios from 'axios';

import { RELAYER_URL } from '../constants/envVars';
import type {
  APIResponse,
  RelayerBlockInfo,
  TransactionData,
} from '../domain/relayerApi';
import { providers } from '../provider/providers';
import { RelayerAPIService } from './RelayerAPIService';

jest.mock('axios');
jest.mock('../constants/envVars');

const data1 = {
  Message: {
    Id: 1,
    To: '0x123',
    Owner: '0x123',
    Sender: '0x123',
    RefundAddress: '0x123',
    Data: '0x123',
    SrcChainId: 1,
    DestChainId: 2,
    Memo: '',
    GasLimit: '1',
    CallValue: '1',
    DepositValue: '1',
    ProcessingFee: '1',
  },
  Raw: {
    transactionHash: '0x123',
  },
} as TransactionData;

const data2 = {
  Message: {
    Id: 2,
    To: '0x456',
    Owner: '0x456',
    Sender: '0x456',
    RefundAddress: '0x456',
    Data: '0x456',
    SrcChainId: 2,
    DestChainId: 1,
    Memo: '',
    GasLimit: '1',
    CallValue: '1',
    DepositValue: '1',
    ProcessingFee: '1',
  },
  Raw: {
    transactionHash: '0x456',
  },
} as TransactionData;

const dataFromAPI = {
  items: [
    {
      id: 1,
      data: data1,
      status: 0,
      amount: '1000000000000000000',
      canonicalTokenSymbol: 'ETH',
      messageOwner: '0x123',
      msgHash: '0x123',
      canonicalTokenAddress: '0x123',
      canonicalTokenName: 'ETH',
      canonicalTokenDecimals: 18,
    },
    {
      id: 2,
      data: data2,
      status: 1,
      amount: '2000000000000000000',
      canonicalTokenSymbol: 'BLL',
      messageOwner: '0x456',
      msgHash: '0x456',
      canonicalTokenAddress: '0x456',
      canonicalTokenName: 'BLL',
      canonicalTokenDecimals: 18,
    },
  ],
} as APIResponse;

const blockInfoFromAPI = [
  {
    chainID: 1,
    latestProcessedBlock: 2,
    latestBlock: 3,
  },
  {
    chainID: 2,
    latestProcessedBlock: 4,
    latestBlock: 5,
  },
] as RelayerBlockInfo[];

const baseUrl = RELAYER_URL.replace(/\/$/, '');
const relayerApi = new RelayerAPIService(RELAYER_URL, providers);

describe('RelayerAPIService', () => {
  it('should get transactions from API', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: dataFromAPI,
    });

    const data = await relayerApi.getTransactionsFromAPI({
      address: '0x123',
      chainID: 1,
      event: 'MessageSent',
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: '0x123', chainID: 1, event: 'MessageSent' },
    });

    // Test return value
    expect(data).toEqual(dataFromAPI);
  });

  it('cannot get transactions from API', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(
      relayerApi.getTransactionsFromAPI({
        address: '0x123',
        chainID: 1,
        event: 'MessageSent',
      }),
    ).rejects.toThrowError('could not fetch transactions from API');
  });

  // TODO: finish this test
  it('should get all bridge transaction by address', async () => {
    axios.get = jest.fn().mockResolvedValueOnce({
      data: dataFromAPI,
    });

    const data = await relayerApi.getAllBridgeTransactionByAddress('0x123', {
      page: 0,
      size: 100,
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: '0x123', event: 'MessageSent', page: 0, size: 100 },
    });
  });

  it('should get block info', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: {
        data: blockInfoFromAPI,
      },
    });

    const blockInfo = await relayerApi.getBlockInfo();

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/blockInfo`);

    // Test return value
    expect(blockInfo).toEqual(
      new Map([
        [blockInfoFromAPI[0].chainID, blockInfoFromAPI[0]],
        [blockInfoFromAPI[1].chainID, blockInfoFromAPI[1]],
      ]),
    );
  });

  it('cannot get block info', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(relayerApi.getBlockInfo()).rejects.toThrowError(
      'failed to fetch block info',
    );
  });
});
