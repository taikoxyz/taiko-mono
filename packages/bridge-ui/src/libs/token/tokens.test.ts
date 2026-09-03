/**
 * A token the deployment marks `supported: false` is not offered for bridging. The attribute
 * used to be read by nothing, so a configured entry could carry a guard that did not exist:
 * mainnet WETH was marked unsupported, pointed at the wrong Taiko contract, and was bridgeable
 * one way regardless.
 */
vi.mock('$customToken', async () => {
  const { TokenType } = await import('./types');
  const addresses = {
    1: '0x0000000000000000000000000000000000000001',
    2: '0x0000000000000000000000000000000000000002',
  };
  return {
    customToken: [
      { name: 'Plain', symbol: 'PLN', decimals: 18, type: TokenType.ERC20, addresses },
      {
        name: 'Opted in',
        symbol: 'OPT',
        decimals: 18,
        type: TokenType.ERC20,
        addresses,
        attributes: [{ supported: true }],
      },
      {
        name: 'Opted out',
        symbol: 'OUT',
        decimals: 18,
        type: TokenType.ERC20,
        addresses,
        attributes: [{ wrapped: true, supported: false }],
      },
    ],
  };
});

import { isSupported, testERC20Tokens, tokens } from './tokens';

const bySymbol = (symbol: string) => testERC20Tokens.find((token) => token.symbol === symbol)!;

describe('isSupported', () => {
  it('treats a token that says nothing about it as supported', () => {
    expect(isSupported(bySymbol('PLN'))).toBe(true);
  });

  it('treats an explicit opt-in as supported', () => {
    expect(isSupported(bySymbol('OPT'))).toBe(true);
  });

  it('treats an explicit opt-out as unsupported', () => {
    expect(isSupported(bySymbol('OUT'))).toBe(false);
  });
});

describe('the bridgeable token list', () => {
  it('offers ETH and every ERC20 the deployment has not opted out', () => {
    expect(tokens.map((token) => token.symbol)).toEqual(['ETH', 'PLN', 'OPT']);
  });

  it('leaves the opted-out ERC20 visible to the faucet', () => {
    // The faucet filters on `mintable` itself; a test token can be mintable yet not bridgeable
    expect(testERC20Tokens.map((token) => token.symbol)).toContain('OUT');
  });
});
