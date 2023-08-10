import { getContract } from '@wagmi/core';

import { getCrossChainAddress } from './getCrossChainAddress';
import { testERC20Tokens } from './tokens';
import { type Token, TokenType } from './types';

vi.mock('@wagmi/core');
vi.mock('$abi');
vi.mock('$libs/chain');

const MockedETH: Token = {
  name: '',
  addresses: {},
  symbol: '',
  decimals: 0,
  type: TokenType.ETH,
};

describe('getCrossChainAddress', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should return null for ETH type tokens', async () => {
    const result = await getCrossChainAddress({
      token: MockedETH,
      srcChainId: 1,
      destChainId: 2,
    });
    expect(result).toBeNull();
  });

  //Todo: more tests
});
