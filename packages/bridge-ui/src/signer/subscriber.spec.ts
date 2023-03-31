import type { Signer, Transaction } from 'ethers';
import type { BridgeTransaction } from '../domain/transaction';
import type { Token } from '../domain/token';
import { subscribeToSigner } from './subscriber';
import { relayerApi } from '../relayer-api/relayerApi';
import { storageService, tokenService } from '../storage/services';

jest.mock('../constants/envVars');
jest.mock('../relayer-api/relayerApi');
jest.mock('../storage/services');
jest.mock('../store/transaction');
jest.mock('../store/token');

const address = '0x123';
const signer = {
  getAddress: () => Promise.resolve(address),
} as Signer;

const apiTxs = [{ hash: '0x456' }, { hash: '0x789' }] as BridgeTransaction[];
const txs = [{ hash: '0x123' }, { hash: '0x456' }] as Transaction[];
const tokens = [{}, {}] as Token[];

beforeAll(() => {
  (relayerApi.getAllBridgeTransactionByAddress as jest.Mock).mockResolvedValue(
    apiTxs,
  );

  (storageService.getAllByAddress as jest.Mock).mockResolvedValue(txs);

  (tokenService.getTokens as jest.Mock).mockReturnValue(tokens);
});

describe('subscribeToSigner', () => {
  it('tests subscribeToSigner', async () => {
    await subscribeToSigner(signer);

    expect(relayerApi.getAllBridgeTransactionByAddress).toHaveBeenCalledWith(
      address,
    );

    expect(storageService.getAllByAddress).toHaveBeenCalledWith(address);
  });
});
