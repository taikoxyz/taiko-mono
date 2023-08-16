import { getContract, type GetContractResult } from '@wagmi/core';

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';

import { getAddress } from './getAddress';
import { ETHToken, testERC20Tokens } from './tokens';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const HORSEToken = testERC20Tokens[1];

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
