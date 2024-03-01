import { L1_ADDRESSES, L2_A_ADDRESSES, L3_ADDRESSES } from '../src/tests/mocks/addresses';

export const routingContractsMap = {
  1: {
    2: L1_ADDRESSES,
  },
  2: {
    1: L2_A_ADDRESSES,
  },
  3: {
    2: L3_ADDRESSES,
  },
};
