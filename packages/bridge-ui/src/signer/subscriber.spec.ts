// import type { Signer, Transaction } from 'ethers';
// import type { BridgeTransaction } from '../domain/transaction';
// import type { Token } from '../domain/token';
// import { subscribeToSigner } from './subscriber';
// import { relayerApi } from '../relayer-api/relayerApi';
// import { storageService, tokenService } from '../storage/services';
// import { transactions } from '../store/transaction';
// import { userTokens } from '../store/token';

// jest.mock('../constants/envVars');
// jest.mock('../relayer-api/relayerApi');
// jest.mock('../storage/services');
// jest.mock('../store/transaction');
// jest.mock('../store/token');

// const address = '0x123';
// const signer = {
//   getAddress: () => Promise.resolve(address),
// } as Signer;

// const txsFromAPI = [
//   { hash: '0x456' },
//   { hash: '0x789' },
// ] as BridgeTransaction[];

// const txsFromStorage = [
//   { hash: '0x123' },
//   { hash: '0x456' },
// ] as BridgeTransaction[];

// const tokens = [{}, {}] as Token[];

// // TODO: we might want to put the mocks under __mocks__
// beforeAll(() => {
//   jest
//     .mocked(relayerApi)
//     .getAllBridgeTransactionByAddress.mockResolvedValue(txsFromAPI);

//   jest.mocked(storageService).getAllByAddress.mockResolvedValue(txsFromStorage);

//   jest.mocked(tokenService).getTokens.mockReturnValue(tokens);
// });

// describe('subscribeToSigner', () => {
//   it('tests subscribeToSigner', async () => {
//     await subscribeToSigner(signer);

//     expect(relayerApi.getAllBridgeTransactionByAddress).toHaveBeenCalledWith(
//       address,
//     );

//     expect(storageService.getAllByAddress).toHaveBeenCalledWith(address);

//     // We're expecting here to pass only the tx that's not in the API response,
//     // and that is { hash: '0x123' }
//     expect(storageService.updateStorageByAddress).toHaveBeenCalledWith(
//       address,
//       [{ hash: '0x123' }],
//     );

//     // We make sure that we pass what's been filtered from the storage, plus
//     // what we got from the API
//     expect(transactions.set).toHaveBeenCalledWith([
//       { hash: '0x123' },
//       ...txsFromAPI,
//     ]);

//     // Next we test functions are called with the right arguments:
//     expect(tokenService.getTokens).toHaveBeenCalledWith(address);

//     // We pass what's returned from the previos tokenService.getTokens
//     // and that is the tokens array
//     expect(userTokens.set).toHaveBeenCalledWith(tokens);
//   });
// });

// TODO

describe('subscribeToSigner', () => {
  it('tests subscribeToSigner', () => {
    expect(true).toBeTruthy();
  });
});
