import { describe, expect, it } from 'vitest';

import { toTsLiteral } from '../utils/toTsLiteral';
import { _formatObjectToTsLiteral as formatBridgeConfig } from './generateBridgeConfig';
import { _formatObjectToTsLiteral as formatChainConfig } from './generateChainConfig';
import { _formatObjectToTsLiteral as formatCustomTokenConfig } from './generateCustomTokenConfig';
import { _formatObjectToTsLiteral as formatEventIndexerConfig } from './generateEventIndexerConfig';
import { _formatObjectToTsLiteral as formatRelayerConfig } from './generateRelayerConfig';

const quoteBreakout = `safe"; globalThis.__codegenExecuted = true; "`;

describe('bridge-ui generated TypeScript literals', () => {
  it('does not treat config keys as internal serializer expressions', () => {
    const literal = toTsLiteral({ __tsExpression: 'globalThis.__codegenExecuted = true' });

    expect(literal).toBe('{"__tsExpression": "globalThis.__codegenExecuted = true"}');
  });

  it('serializes bridge config keys and string values as data', () => {
    const literal = formatBridgeConfig({
      [`1${quoteBreakout}`]: {
        '2': {
          bridgeAddress: quoteBreakout,
          erc20VaultAddress: quoteBreakout,
          erc721VaultAddress: quoteBreakout,
          erc1155VaultAddress: quoteBreakout,
          signalServiceAddress: quoteBreakout,
        },
      },
    });

    expect(literal).toContain(JSON.stringify(`1${quoteBreakout}`));
    expect(literal).toContain(JSON.stringify(quoteBreakout));
    expect(literal).not.toContain(`"${quoteBreakout}"`);
  });

  it('serializes chain metadata as data while preserving validated LayerType expressions', () => {
    const literal = formatChainConfig({
      1: {
        id: 1,
        name: quoteBreakout,
        icon: quoteBreakout,
        type: 'L1',
        rpcUrls: { default: { http: [quoteBreakout] } },
        nativeCurrency: { name: quoteBreakout, symbol: quoteBreakout, decimals: 18 },
        blockExplorers: { default: { name: quoteBreakout, url: quoteBreakout } },
      },
    });

    expect(literal).toContain('"type": LayerType.L1');
    expect(literal).toContain(JSON.stringify(quoteBreakout));
    expect(literal).not.toContain(`"${quoteBreakout}"`);
  });

  it('serializes custom token data and rejects unrecognized TokenType values', () => {
    const literal = formatCustomTokenConfig([
      {
        name: quoteBreakout,
        symbol: quoteBreakout,
        decimals: 18,
        type: 'ERC20',
        addresses: { 1: quoteBreakout },
      },
    ]);

    expect(literal).toContain('"type": TokenType.ERC20');
    expect(literal).toContain(JSON.stringify(quoteBreakout));
    expect(literal).not.toContain(`"${quoteBreakout}"`);

    expect(() =>
      formatCustomTokenConfig([
        {
          name: 'Bad Token',
          symbol: 'BAD',
          decimals: 18,
          type: `ERC20${quoteBreakout}`,
          addresses: { 1: quoteBreakout },
        },
      ]),
    ).toThrow(/Invalid TokenType/);
  });

  it('serializes event indexer URLs as data', () => {
    const literal = formatEventIndexerConfig([{ chainIds: [1], url: quoteBreakout }]);

    expect(literal).toContain(JSON.stringify(quoteBreakout));
    expect(literal).not.toContain(`"${quoteBreakout}"`);
  });

  it('serializes relayer URLs as data', () => {
    const literal = formatRelayerConfig([{ chainIds: [1], url: quoteBreakout }]);

    expect(literal).toContain(JSON.stringify(quoteBreakout));
    expect(literal).not.toContain(`"${quoteBreakout}"`);
  });
});
