import { describe, expect, it } from 'vitest';
import { runInNewContext } from 'vm';

import type { BridgeConfig } from '../../src/libs/bridge/types';
import { toTsLiteral } from '../utils/toTsLiteral';
import {
  _buildRoutingMap as buildRoutingMap,
  _formatObjectToTsLiteral as formatBridgeConfig,
} from './generateBridgeConfig';
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

  it('keeps reserved bridge route keys as data without prototype pollution', () => {
    const pollutionKey = '__bridgeConfigPollutionProbe';
    const addresses = {
      bridgeAddress: '0x1',
      erc20VaultAddress: '0x2',
      erc721VaultAddress: '0x3',
      erc1155VaultAddress: '0x4',
      signalServiceAddress: '0x5',
    } as unknown as BridgeConfig['addresses'];

    try {
      const routingContractsMap = buildRoutingMap({
        configuredBridges: [{ source: '__proto__', destination: pollutionKey, addresses }],
      });

      expect(Object.hasOwn(Object.prototype, pollutionKey)).toBe(false);
      expect(Object.hasOwn(routingContractsMap, '__proto__')).toBe(true);

      const literal = formatBridgeConfig(routingContractsMap);
      expect(literal).toContain('["__proto__"]');

      const generated = runInNewContext(`(${literal})`);
      expect(Object.keys(generated)).toEqual(['__proto__']);
      expect(Object.hasOwn(Object.getPrototypeOf(generated), pollutionKey)).toBe(false);
      expect(generated['__proto__'][pollutionKey]).toEqual(addresses);
    } finally {
      delete (Object.prototype as unknown as Record<string, unknown>)[pollutionKey];
    }
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

  it('preserves nested chain type fields as data', () => {
    const literal = formatChainConfig({
      1: {
        id: 1,
        name: 'Example',
        icon: 'example',
        type: 'L1',
        rpcUrls: { default: { http: ['https://rpc.example'] } },
        nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
        blockExplorers: { default: { name: 'Explorer', url: 'https://explorer.example' } },
        custom: { type: 'rpc' },
      },
    });

    expect(literal).toContain('"type": LayerType.L1');
    expect(literal).toContain('"custom": {"type": "rpc"}');
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
