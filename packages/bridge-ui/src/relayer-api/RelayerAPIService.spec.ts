import axios from 'axios';
import { providers } from '../provider/providers';
import { RELAYER_URL } from '../constants/envVars';
import { RelayerAPIService } from './RelayerAPIService';
import type {
  APIResponse,
  RelayerBlockInfo,
  TransactionData,
} from '../domain/relayerApi';

jest.mock('../constants/envVars');
jest.mock('axios');

const data1 = {
  Message: {},
  Raw: {},
} as TransactionData;

const data2 = {
  Message: {},
  Raw: {},
} as TransactionData;

const dataFromAPI = {
  items: [
    { id: 1, data: data1 },
    { id: 2, data: data2 },
  ],
} as APIResponse;

const blockInfoFromAPI = [
  {
    ChainID: 1,
    LatestProcessedBlock: 2,
    LatestBlock: 3,
  },
  {
    ChainID: 2,
    LatestProcessedBlock: 4,
    LatestBlock: 5,
  },
] as RelayerBlockInfo[];

const baseUrl = RELAYER_URL.replace(/\/$/, '');
const relayerApi = new RelayerAPIService(RELAYER_URL, providers);

describe('RelayerAPIService', () => {
  it('should get transactions from API', async () => {
    axios.get = jest.fn().mockResolvedValue({
      data: dataFromAPI,
    });

    const data = await relayerApi.getTransactionsFromAPI({
      address: '0x123',
      chainID: 1,
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: '0x123', chainID: 1 },
    });

    // Test return value
    expect(data).toEqual(dataFromAPI);
  });

  // TODO: Finish this test
  // it('should get all bridge transaction by address', async () => {
  //   axios.get = jest.fn().mockResolvedValue({
  //     data: dataFromAPI,
  //   });

  //   const data = await relayerApi.getAllBridgeTransactionByAddress('0x123', 1);

  //   // Test parameters
  //   expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
  //     params: { address: '0x123', chainID: 1, event: 'MessageSent' },
  //   });
  // });

  it('should get block info', async () => {
    axios.get = jest.fn().mockResolvedValue({
      data: blockInfoFromAPI,
    });

    const blockInfo = await relayerApi.getBlockInfo();

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/blockInfo`);

    // Test return value
    expect(blockInfo).toEqual(
      new Map([
        [blockInfoFromAPI[0].ChainID, blockInfoFromAPI[0]],
        [blockInfoFromAPI[1].ChainID, blockInfoFromAPI[1]],
      ]),
    );
  });
});
