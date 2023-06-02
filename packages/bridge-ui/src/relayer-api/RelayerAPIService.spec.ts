import type { Address } from '@wagmi/core';
import axios from 'axios';

import { RELAYER_URL } from '../constants/envVars';
import type { APIResponse, RelayerBlockInfo } from '../domain/relayerApi';
import { providers } from '../provider/providers';
import blockInfoJson from './__fixtures__/blockInfo.json';
import eventsJson from './__fixtures__/events.json';
import { RelayerAPIService } from './RelayerAPIService';

jest.mock('axios');
jest.mock('../constants/envVars');

const walletAddress: Address = '0x33C887d229B5b99cdfa06B02102f8F75411C56B8';

const baseUrl = RELAYER_URL.replace(/\/$/, '');
const relayerApi = new RelayerAPIService(RELAYER_URL, providers);

describe('RelayerAPIService', () => {
  it('should get transactions from API', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: eventsJson,
    });

    const data = await relayerApi.getTransactionsFromAPI({
      address: walletAddress,
      chainID: 1,
      event: 'MessageSent',
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: walletAddress, chainID: 1, event: 'MessageSent' },
    });

    // Test return value
    expect(data.items.length).toEqual(eventsJson.items.length);
  });

  it('cannot get transactions from API', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(
      relayerApi.getTransactionsFromAPI({
        address: walletAddress,
        chainID: 1,
        event: 'MessageSent',
      }),
    ).rejects.toThrowError('could not fetch transactions from API');
  });

  // TODO: finish this test
  it('should get all bridge transaction by address', async () => {
    axios.get = jest.fn().mockResolvedValueOnce({
      data: eventsJson,
    });

    await relayerApi.getAllBridgeTransactionByAddress(walletAddress, {
      page: 0,
      size: 100,
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: {
        address: walletAddress,
        event: 'MessageSent',
        page: 0,
        size: 100,
      },
    });
  });

  it('should get block info', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: blockInfoJson,
    });

    const blockInfo = await relayerApi.getBlockInfo();

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/blockInfo`);

    // Test return value
    expect(blockInfo).toEqual(
      new Map([
        [blockInfoJson.data[0].chainID, blockInfoJson.data[0]],
        [blockInfoJson.data[1].chainID, blockInfoJson.data[1]],
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
