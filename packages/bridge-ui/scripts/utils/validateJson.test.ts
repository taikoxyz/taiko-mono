import { describe, expect, it } from 'vitest';

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
