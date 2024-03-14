import { IPFSGateway, safeParseUrl } from './safeParseUrl';

describe('safeParseUrl function', () => {
  test('should return input URI when no IPFS prefix is present', () => {
    const uri = 'https://example.com';
    const result = safeParseUrl(uri);
    expect(result).toBe(uri);
  });

  test('should return converted URI using default gateway (IPFS_IO) when IPFS prefix is present', () => {
    const uri = 'ipfs://QmZxBH8G8mMwEobzTgQPAf5NMNU6kx39P7LLeMgQgxneKT';
    const expectedConvertedUri = 'https://ipfs.io/ipfs/QmZxBH8G8mMwEobzTgQPAf5NMNU6kx39P7LLeMgQgxneKT';
    const result = safeParseUrl(uri);
    expect(result).toBe(expectedConvertedUri);
  });

  test('should return converted URI using specified gateway when IPFS prefix is present', () => {
    const uri = 'ipfs://QmZxBH8G8mMwEobzTgQPAf5NMNU6kx39P7LLeMgQgxneKT';
    const expectedConvertedUri = 'https://cloudflare-ipfs.com/ipfs/QmZxBH8G8mMwEobzTgQPAf5NMNU6kx39P7LLeMgQgxneKT';
    const result = safeParseUrl(uri, IPFSGateway.CLOUDFLARE_IPFS_COM);
    expect(result).toBe(expectedConvertedUri);
  });
});
