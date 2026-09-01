import type { Address } from 'viem';

import { isSameNFT, tokenIdentityKey, tokensAreSame } from './tokenIdentity';
import { type Token, TokenType } from './types';

const token = (overrides: Partial<Token>): Token =>
  ({
    name: 'Token',
    symbol: 'TKN',
    decimals: 18,
    type: TokenType.ERC20,
    addresses: {},
    ...overrides,
  }) as Token;

describe('tokensAreSame', () => {
  it('matches tokens sharing a deployment on the same chain, case-insensitively', () => {
    const a = token({ addresses: { 1: '0xAbC0000000000000000000000000000000000001' as Address } });
    const b = token({ symbol: 'OTHER', addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    expect(tokensAreSame(a, b)).toBe(true);
  });

  it('does not match unrelated tokens at the same address on different chains', () => {
    const a = token({ addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    const b = token({ addresses: { 167000: '0xabc0000000000000000000000000000000000001' as Address } });
    expect(tokensAreSame(a, b)).toBe(false);
  });

  it('falls back to the symbol only when no addresses are known', () => {
    expect(tokensAreSame(token({}), token({}))).toBe(true);
    expect(tokensAreSame(token({}), token({ symbol: 'OTHER' }))).toBe(false);
  });

  describe('when only one side carries addresses', () => {
    it('does not treat them as the same token', () => {
      const withAddresses = { symbol: 'TKN', addresses: { 1: '0x1111111111111111111111111111111111111111' } } as never;
      const withoutAddresses = { symbol: 'TKN', addresses: {} } as never;

      // An identity that cannot be established must not authorise storeToken to suppress
      // an entry or removeToken to delete one
      expect(tokensAreSame(withAddresses, withoutAddresses)).toBe(false);
      expect(tokensAreSame(withoutAddresses, withAddresses)).toBe(false);
    });

    it('still matches two address-less entries by symbol', () => {
      const a = { symbol: 'TKN', addresses: {} } as never;
      const b = { symbol: 'TKN', addresses: {} } as never;

      expect(tokensAreSame(a, b)).toBe(true);
    });
  });
});

describe('tokenIdentityKey', () => {
  it('produces distinct keys for same-symbol tokens at different deployments', () => {
    const a = token({ addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    const b = token({ addresses: { 1: '0xdef0000000000000000000000000000000000002' as Address } });
    expect(tokenIdentityKey(a)).not.toEqual(tokenIdentityKey(b));
  });

  it('falls back to the symbol for address-less tokens', () => {
    expect(tokenIdentityKey(token({}))).toBe('TKN');
  });
});

describe('isSameNFT', () => {
  const nft = (tokenId: number | string, address: string) => ({ tokenId, addresses: { 1: address } }) as never;

  const ADDRESS = '0x1111111111111111111111111111111111111111';

  it('matches equal NFTs held in different objects', () => {
    // Every page load rebuilds these across the /api/nft JSON boundary, so a kept
    // selection never matched the freshly parsed list and rendered unchecked
    expect(isSameNFT(nft(7, ADDRESS), nft(7, ADDRESS))).toBe(true);
  });

  it('matches a token id that crossed JSON as a string', () => {
    expect(isSameNFT(nft(7, ADDRESS), nft('7', ADDRESS))).toBe(true);
  });

  it('does not match a different token id at the same contract', () => {
    expect(isSameNFT(nft(7, ADDRESS), nft(8, ADDRESS))).toBe(false);
  });

  it('does not match the same token id at a different contract', () => {
    expect(isSameNFT(nft(7, ADDRESS), nft(7, '0x2222222222222222222222222222222222222222'))).toBe(false);
  });

  it('does not match when either side is missing', () => {
    expect(isSameNFT(null, nft(7, ADDRESS))).toBe(false);
    expect(isSameNFT(nft(7, ADDRESS), undefined)).toBe(false);
  });
});
