import { getContract, type GetContractResult } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { getAddress } from './getAddress';
import { ETHToken } from './tokens';
import { type Token, TokenType } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const PUBLIC_L1_CHAIN_ID = 11155111;
const PUBLIC_L2_CHAIN_ID = 1670005;

const L1_TOKEN_ADDRESS = '0x123456';

const HORSEToken: Token = {
  name: 'MockToken',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: L1_TOKEN_ADDRESS,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  symbol: 'MOCK',
  decimals: 18,
  type: TokenType.ERC20,
};

const mockTokenContract = {
  read: {
    canonicalToBridged: vi.fn(),
    isBridgedToken: vi.fn(),
    bridgedToCanonical: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

describe('getAddress', () => {
  beforeEach(() => {
    vi.resetAllMocks();

    vi.mocked(getContract).mockReturnValue(mockTokenContract);
  });

  describe('ETH Tests', () => {
    it('should return undefined if ETH', async () => {
      expect(await getAddress({ token: ETHToken, srcChainId: Number(PUBLIC_L1_CHAIN_ID) })).toBeUndefined();
    });
  });

  describe('ERC20 Tests', () => {
    it('should return the address if ERC20 and has address on the source chain', async () => {
      expect(await getAddress({ token: HORSEToken, srcChainId: Number(PUBLIC_L1_CHAIN_ID) })).toEqual(
        HORSEToken.addresses[PUBLIC_L1_CHAIN_ID],
      );
    });

    it('should return undefined if ERC20 and has no address on the source chain and no destination chain is is passed in', async () => {
      expect(await getAddress({ token: HORSEToken, srcChainId: Number(PUBLIC_L2_CHAIN_ID) })).toBeUndefined();
    });
  });
});
