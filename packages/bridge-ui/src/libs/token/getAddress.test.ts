import { zeroAddress } from 'viem';

import { getAddress } from './getAddress';
import { getTokenAddresses } from './getTokenAddresses';
import { ETHToken } from './tokens';
import { type Token, TokenType } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

vi.mock('./getTokenAddresses');

const PUBLIC_L1_CHAIN_ID = 11155111;
const PUBLIC_L2_CHAIN_ID = 1670005;

const L1_TOKEN_ADDRESS = '0x123456';
const L2_TOKEN_ADDRESS = '0x654321';

let HORSEToken: Token;

describe('getAddress', () => {
  beforeEach(() => {
    HORSEToken = {
      name: 'MockToken',
      addresses: {
        [PUBLIC_L1_CHAIN_ID]: L1_TOKEN_ADDRESS,
        [PUBLIC_L2_CHAIN_ID]: zeroAddress,
      },
      symbol: 'MOCK',
      decimals: 18,
      type: TokenType.ERC20,
    };
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

    it('should return the bridged address if ERC20 and has no address on the source chain and has a destination chain', async () => {
      const BridgedHORSEToken = HORSEToken;
      BridgedHORSEToken.addresses[PUBLIC_L2_CHAIN_ID] = L2_TOKEN_ADDRESS;

      vi.mocked(getTokenAddresses).mockResolvedValueOnce({
        bridged: {
          address: L2_TOKEN_ADDRESS,
          chainId: PUBLIC_L2_CHAIN_ID,
        },
        canonical: {
          address: L1_TOKEN_ADDRESS,
          chainId: PUBLIC_L1_CHAIN_ID,
        },
      });

      expect(
        await getAddress({
          token: BridgedHORSEToken,
          srcChainId: Number(PUBLIC_L2_CHAIN_ID),
          destChainId: Number(PUBLIC_L1_CHAIN_ID),
        }),
      ).toEqual(BridgedHORSEToken.addresses[PUBLIC_L2_CHAIN_ID]);
    });

    it('should return undefined if ERC20 and has no address on the source chain and no destination chain is passed in', async () => {
      expect(await getAddress({ token: HORSEToken, srcChainId: Number(PUBLIC_L2_CHAIN_ID) })).toBeUndefined();
    });

    it('should return the canonical address when the canonical deployment is on the source chain', async () => {
      // The token object does not know its source-chain address, but the canonical
      // deployment lives there; the bridged deployment is on the destination chain
      // and must NOT be returned as a source-chain address
      const tokenWithoutSrcAddress: Token = {
        ...HORSEToken,
        addresses: {
          [PUBLIC_L1_CHAIN_ID]: zeroAddress,
          [PUBLIC_L2_CHAIN_ID]: L2_TOKEN_ADDRESS,
        },
      };

      vi.mocked(getTokenAddresses).mockResolvedValueOnce({
        canonical: {
          address: L1_TOKEN_ADDRESS,
          chainId: PUBLIC_L1_CHAIN_ID,
        },
        bridged: {
          address: L2_TOKEN_ADDRESS,
          chainId: PUBLIC_L2_CHAIN_ID,
        },
      });

      expect(
        await getAddress({
          token: tokenWithoutSrcAddress,
          srcChainId: Number(PUBLIC_L1_CHAIN_ID),
          destChainId: Number(PUBLIC_L2_CHAIN_ID),
        }),
      ).toEqual(L1_TOKEN_ADDRESS);
    });
  });
});
