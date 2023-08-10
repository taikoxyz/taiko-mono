import { type Address, getContract, type GetContractResult } from '@wagmi/core';

import { tokenVaultABI } from '$abi';
import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';
import { chainContractsMap } from '$libs/chain';

import { getAddress } from './getAddress';
import { ETHToken, testERC20Tokens } from './tokens';
import { type Token, TokenType } from './types';

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

  describe('Address Retrieval Tests', () => {
    it('should return the address of deployed ERC20 token', async () => {
      vi.mocked(mockTokenContract.read.isBridgedToken).mockResolvedValue(false);
      vi.mocked(mockTokenContract.read.canonicalToBridged).mockResolvedValue('0x456789');

      expect(
        await getAddress({
          token: HORSEToken,
          srcChainId: Number(PUBLIC_L2_CHAIN_ID),
          destChainId: Number(PUBLIC_L1_CHAIN_ID),
        }),
      ).toEqual('0x456789');

      expect(mockTokenContract.read.canonicalToBridged).toHaveBeenCalledWith([
        BigInt(1),
        HORSEToken.addresses[PUBLIC_L1_CHAIN_ID],
      ]);
      expect(getContract).toHaveBeenCalledWith({
        abi: tokenVaultABI,
        address: chainContractsMap[PUBLIC_L2_CHAIN_ID].tokenVaultAddress,
        chainId: Number(PUBLIC_L2_CHAIN_ID),
      });
    });
  });

  describe('Bridged Address Tests (L3)', () => {
    it('should return the bridged Address if the destination is also already a bridged (e.g. L3->L2)', async () => {
      vi.mocked(mockTokenContract.read.isBridgedToken).mockResolvedValue(true);
      vi.mocked(mockTokenContract.read.bridgedToCanonical).mockResolvedValue([
        BigInt(1234),
        '0x111111',
        18,
        'L3Token',
        'L3T',
      ]);

      const L3Token = {
        name: 'L3Token',
        symbol: 'L3T',
        addresses: {
          [PUBLIC_L1_CHAIN_ID]: '0x123456' as Address,
          [PUBLIC_L2_CHAIN_ID]: '0x654321' as Address,
        },
        decimals: 18,
        type: TokenType.ERC20,
      } as Token;

      expect(
        await getAddress({
          token: L3Token,
          srcChainId: Number(PUBLIC_L2_CHAIN_ID),
          destChainId: Number(PUBLIC_L1_CHAIN_ID),
        }),
      ).toEqual('0x111111' as Address);

      expect(mockTokenContract.read.isBridgedToken).toHaveBeenCalledWith([L3Token.addresses[PUBLIC_L1_CHAIN_ID]]);

      // expect(mockTokenContract.read.bridgedToCanonical).toHaveBeenCalledWith([
      //   L3Token.addresses[PUBLIC_L2_CHAIN_ID],
      // ]);
    });
  });
});
