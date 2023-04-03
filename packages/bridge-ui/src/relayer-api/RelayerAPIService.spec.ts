import axios, { type AxiosResponse } from 'axios';
import { providers } from '../provider/providers';
import { RELAYER_URL } from '../constants/envVars';
import { RelayerAPIService } from './RelayerAPIService';
import type { APIResponse } from '../domain/relayerApi';
import type { BridgeTransaction } from '../domain/transaction';

jest.mock('../constants/envVars');
jest.mock('axios');

const txsFromAPI = [
  { hash: '0x456' },
  { hash: '0x789' },
] as BridgeTransaction[];

const baseUrl = RELAYER_URL.replace(/\/$/, '');
const relayerApi = new RelayerAPIService(RELAYER_URL, providers);

beforeAll(() => {
  axios.get = jest.fn().mockResolvedValue({
    data: txsFromAPI,
  });
});

describe('RelayerAPIService', () => {
  it('should get transactions from API', async () => {
    const txs = await relayerApi.getTransactionsFromAPI({
      address: '0x123',
      chainID: 1,
    });

    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: '0x123', chainID: 1 },
    });

    expect(txs).toEqual(txsFromAPI);
  });

  // it('should get all bridge transaction by address', async () => {
  //   const txs = await relayerApi.getAllBridgeTransactionByAddress('0x123');

  //   expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
  //     params: { address: '0x123' },
  //   });

  //   expect(txs).toEqual(txsFromAPI);
  // });
});
