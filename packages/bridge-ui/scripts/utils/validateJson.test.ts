import { describe, expect, it } from 'vitest';

import configuredChainsSchema from '../../config/schemas/configuredChains.schema.json';
import configuredEventIndexerSchema from '../../config/schemas/configuredEventIndexer.schema.json';
import configuredRelayerSchema from '../../config/schemas/configuredRelayer.schema.json';
import { validateJsonAgainstSchema } from './validateJson';

const schemas = [
  {
    name: 'event indexer',
    rootKey: 'configuredEventIndexer',
    schema: configuredEventIndexerSchema,
  },
  {
    name: 'relayer',
    rootKey: 'configuredRelayer',
    schema: configuredRelayerSchema,
  },
] as const;

describe.each(schemas)('$name URL validation', ({ rootKey, schema }) => {
  const validateUrl = (url: string) => {
    return validateJsonAgainstSchema(
      {
        [rootKey]: [{ chainIds: [1], url }],
      } as unknown as JSON,
      schema,
    );
  };

  it('accepts credential-free HTTP URLs with IPv6 hosts', () => {
    expect(validateUrl('http://[::1]:4102')).toBe(true);
    expect(validateUrl('https://[2001:db8::1]/api')).toBe(true);
  });

  it('rejects URLs containing credentials', () => {
    expect(validateUrl('https://user:password@example.com')).toBe(false);
  });
});

describe('chain RPC URL validation', () => {
  /** One configured chain, shaped like config/sample/configuredChains.example */
  const chainsWithRpc = (http: string[]) =>
    ({
      configuredChains: [
        {
          '123456': {
            name: 'Chain Name 1',
            type: 'L1',
            icon: 'path/or/url/to/icon1',
            rpcUrls: { default: { http } },
            nativeCurrency: { name: 'Currency1', symbol: 'SYM1', decimals: 18 },
            blockExplorers: { default: { name: 'Explorer 1', url: 'https://explorer.chain1.url/' } },
          },
        },
      ],
    }) as unknown as JSON;

  it('accepts an http(s) endpoint', () => {
    expect(validateJsonAgainstSchema(chainsWithRpc(['https://rpc.chain1.url']), configuredChainsSchema)).toBe(true);
  });

  it('rejects an empty endpoint', () => {
    // createTransports throws at module load on a falsy URL, which takes the whole client
    // bundle down rather than one chain's reads. minItems alone let an empty string through:
    // it is a valid `string`.
    expect(validateJsonAgainstSchema(chainsWithRpc(['']), configuredChainsSchema)).toBe(false);
  });

  it('rejects an endpoint that is not http(s), or carries credentials', () => {
    expect(validateJsonAgainstSchema(chainsWithRpc(['ws://rpc.chain1.url']), configuredChainsSchema)).toBe(false);
    expect(validateJsonAgainstSchema(chainsWithRpc(['https://user:pw@rpc.chain1.url']), configuredChainsSchema)).toBe(
      false,
    );
  });

  it('still rejects a chain with no endpoint at all', () => {
    expect(validateJsonAgainstSchema(chainsWithRpc([]), configuredChainsSchema)).toBe(false);
  });
});
