import axios from 'axios';
import { providers } from '../provider/providers';
import { RELAYER_URL } from '../constants/envVars';
import { RelayerAPIService } from './RelayerAPIService';
import type { BridgeTransaction } from '../domain/transaction';
import type { RelayerBlockInfo } from '../domain/relayerApi';

jest.mock('../constants/envVars');
jest.mock('axios');

const txsFromAPI = [
  { hash: '0x456' },
  { hash: '0x789' },
] as BridgeTransaction[];

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
      data: txsFromAPI,
    });

    const txs = await relayerApi.getTransactionsFromAPI({
      address: '0x123',
      chainID: 1,
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: '0x123', chainID: 1 },
    });

    // Test return value
    expect(txs).toEqual(txsFromAPI);
  });

  // it('should get all bridge transaction by address', async () => {
  //   const txs = await relayerApi.getAllBridgeTransactionByAddress('0x123');

  //   expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
  //     params: { address: '0x123' },
  //   });

  //   expect(txs).toEqual(txsFromAPI);
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
