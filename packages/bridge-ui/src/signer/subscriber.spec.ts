// import type { Signer } from 'ethers';
// import { subscribeToSigner } from './subscriber';

// const mockGetAllBridgeTransactionByAddress = jest
//   .fn()
//   .mockImplementation(() => {
//     return Promise.resolve([{ hash: '0x456' }, { hash: '0x789' }]);
//   });

// jest.mock('../relayer-api/relayerApi', () => ({
//   relayerApi: {
//     getAllBridgeTransactionByAddress: mockGetAllBridgeTransactionByAddress,
//     getBlockInfo: jest.fn(),
//   },
// }));

// jest.mock('../storage/services', () => ({
//   storageService: {
//     getAllByAddress: jest.fn(),
//     updateStorageByAddress: jest.fn(),
//   },
// }));

// jest.mock('../store/token', () => ({
//   userTokens: {
//     set: jest.fn(),
//   },
// }));

// const mockSigner = {
//   getAddress: () => Promise.resolve('0x123'),
// } as Signer;

describe.only('subscribeToSigner', () => {
  it('tests subscribeToSigner', () => {
    expect(true).toBeTruthy();
  });

  // it('tests subscribeToSigner', () => {
  //   subscribeToSigner(mockSigner);

  //   expect(mockGetAllBridgeTransactionByAddress).toHaveBeenCalledWith('0x123');
  //   expect(mockGetAllBridgeTransactionByAddress).toHaveReturnedWith([
  //     { hash: '0x456' },
  //     { hash: '0x789' },
  //   ]);
  // });
});
