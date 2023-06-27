import type { Signer } from 'ethers';

import type { PaginationInfo, RelayerBlockInfo } from '../domain/relayerApi';
import type { Token } from '../domain/token';
import type { BridgeTransaction } from '../domain/transaction';
import { relayerApi } from '../relayer-api/relayerApi';
import { storageService, tokenService } from '../storage/services';
import { paginationInfo, relayerBlockInfoMap } from '../store/relayerApi';
import { transactions } from '../store/transaction';
import { userTokens } from '../store/userToken';
import { subscribeToSigner } from './subscriber';

jest.mock('../constants/envVars');
jest.mock('../relayer-api/relayerApi');
jest.mock('../storage/services');
jest.mock('../store/transaction');
jest.mock('../store/relayerApi');
jest.mock('../store/userToken');

const address = '0x123';
const signer = {
  getAddress: () => Promise.resolve(address),
} as Signer;

const txsFromAPI = [
  { hash: '0x456' },
  { hash: '0x789' },
] as BridgeTransaction[];

const pageInfoFromAPI = {} as PaginationInfo;

const txsFromStorage = [
  { hash: '0x123' },
  { hash: '0x456' },
] as BridgeTransaction[];

const blockInfoMap = new Map() as Map<number, RelayerBlockInfo>;

const tokens = [{}, {}] as Token[];

// TODO: we might want to put the mocks under __mocks__
beforeAll(() => {
  jest.mocked(relayerApi).getAllBridgeTransactionByAddress.mockResolvedValue({
    txs: txsFromAPI,
    paginationInfo: pageInfoFromAPI,
  });

  jest.mocked(relayerApi).getBlockInfo.mockResolvedValue(blockInfoMap);

  jest.mocked(storageService).getAllByAddress.mockResolvedValue(txsFromStorage);

  jest.mocked(tokenService).getTokens.mockReturnValue(tokens);
});

describe('subscribeToSigner', () => {
  it('tests subscribeToSigner with new signer', async () => {
    await subscribeToSigner(signer);

    expect(relayerApi.getAllBridgeTransactionByAddress).toHaveBeenCalledWith(
      address,
      { page: 0, size: 100 },
    );

    expect(relayerApi.getBlockInfo).toHaveBeenCalled();
    expect(relayerBlockInfoMap.set).toHaveBeenCalledWith(blockInfoMap);
    expect(storageService.getAllByAddress).toHaveBeenCalledWith(address);

    // We're expecting here to pass only the tx that's not in the API response,
    // and that is { hash: '0x123' }
    expect(storageService.updateStorageByAddress).toHaveBeenCalledWith(
      address,
      [{ hash: '0x123' }],
    );

    // We make sure that we pass what's been filtered from the storage, plus
    // what we got from the API
    expect(transactions.set).toHaveBeenCalledWith([
      { hash: '0x123' },
      ...txsFromAPI,
    ]);

    // Next we test functions are called with the right arguments:
    expect(tokenService.getTokens).toHaveBeenCalledWith(address);

    // We pass what's returned from the previos tokenService.getTokens
    // and that is the tokens array
    expect(userTokens.set).toHaveBeenCalledWith(tokens);

    expect(paginationInfo.set).toHaveBeenCalledWith(pageInfoFromAPI);

    // We make sure calling it again with the same signer doesn't
    // run the same code again. There is no need for that
    await subscribeToSigner(signer);

    expect(relayerApi.getAllBridgeTransactionByAddress).toHaveBeenCalledTimes(
      1,
    );
    expect(relayerApi.getBlockInfo).toHaveBeenCalledTimes(1);
    expect(storageService.getAllByAddress).toHaveBeenCalledTimes(1);
    expect(storageService.updateStorageByAddress).toHaveBeenCalledTimes(1);
    expect(tokenService.getTokens).toHaveBeenCalledTimes(1);
  });

  it('tests subscribeToSigner with no signer', async () => {
    await subscribeToSigner(null);
    expect(transactions.set).toHaveBeenCalledWith([]);
    expect(userTokens.set).toHaveBeenCalledWith([]);
    expect(paginationInfo.set).toHaveBeenCalledWith(null);
  });

  it('tests subscribeToSigner with a signer that throws', async () => {
    jest
      .mocked(relayerApi)
      .getAllBridgeTransactionByAddress.mockImplementation(() => {
        throw new Error('error');
      });

    const anotherSigner = {
      getAddress: () => Promise.resolve('0x456'),
    } as Signer;

    // `getAllBridgeTransactionByAddress` throws so we expect here:
    // - txsFromAPI = []
    // - pageInfoFromAPI = {}
    await subscribeToSigner(anotherSigner);

    expect(transactions.set).toHaveBeenCalledWith(txsFromStorage);
    expect(paginationInfo.set).toHaveBeenCalledWith({});
  });
});
