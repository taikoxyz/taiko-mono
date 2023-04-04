import type { Signer } from 'ethers';

export const signer = {
  set: jest.fn<void, [Signer]>(),
  subscribe: jest.fn<void, [Function]>(),
};
