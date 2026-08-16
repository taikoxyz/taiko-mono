import { Buffer } from 'buffer';
import { promises as fs } from 'fs';
import path from 'path';
import { describe, expect, it, vi } from 'vitest';

import { toTsLiteral } from '../utils/toTsLiteral';
import { _formatObjectToTsLiteral as formatBridgeConfig, generateBridgeConfig } from './generateBridgeConfig';
import { _formatObjectToTsLiteral as formatChainConfig } from './generateChainConfig';
import { _formatObjectToTsLiteral as formatCustomTokenConfig } from './generateCustomTokenConfig';
import { _formatObjectToTsLiteral as formatEventIndexerConfig } from './generateEventIndexerConfig';
import { _formatObjectToTsLiteral as formatRelayerConfig } from './generateRelayerConfig';

const quoteBreakout = `safe"; globalThis.__codegenExecuted = true; "`;
const generatedBridgeConfigPath = path.resolve(process.cwd(), 'src/generated/bridgeConfig.ts');

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

  it('keeps reserved bridge route keys as data without prototype pollution', async () => {
    const pollutionKey = '__bridgeConfigPollutionProbe';
    let existingGeneratedSource: string | undefined;
    try {
      existingGeneratedSource = await fs.readFile(generatedBridgeConfigPath, 'utf8');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
        throw error;
      }
    }

    vi.stubEnv(
      'CONFIGURED_BRIDGES',
      Buffer.from(
        JSON.stringify({
          configuredBridges: [
            {
              source: '__proto__',
              destination: pollutionKey,
              addresses: {
                bridgeAddress: '0x1',
                erc20VaultAddress: '0x2',
                erc721VaultAddress: '0x3',
                erc1155VaultAddress: '0x4',
                signalServiceAddress: '0x5',
              },
            },
          ],
        }),
      ).toString('base64'),
    );

    try {
      await generateBridgeConfig().buildStart();

      expect(Object.hasOwn(Object.prototype, pollutionKey)).toBe(false);
      const generatedSource = await fs.readFile(generatedBridgeConfigPath, 'utf8');
      expect(generatedSource).toContain('["__proto__"]');
      expect(generatedSource).toContain(`${pollutionKey}: {`);
    } finally {
      delete (Object.prototype as unknown as Record<string, unknown>)[pollutionKey];
      vi.unstubAllEnvs();
      if (existingGeneratedSource === undefined) {
        await fs.rm(generatedBridgeConfigPath, { force: true });
      } else {
        await fs.writeFile(generatedBridgeConfigPath, existingGeneratedSource);
      }
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
