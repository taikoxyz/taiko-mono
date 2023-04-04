import type { Chain } from '../../domain/chain';

export const fromChain = {
  set: jest.fn<void, [Chain]>(),
};

export const toChain = {
  set: jest.fn<void, [Chain]>(),
};
