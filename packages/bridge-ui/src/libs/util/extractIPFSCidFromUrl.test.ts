import { extractIPFSCidFromUrl } from './extractIPFSCidFromUrl';

describe('extractIPFSCidFromUrl', () => {
  test('should return the correct CID when a valid IPFS URL is provided', () => {
    const url = 'https://ipfs.io/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/readme';
    const result = extractIPFSCidFromUrl(url);
    expect(result).toEqual({ cid: 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG' });
  });

  test('should return null when an invalid IPFS URL is provided', () => {
    const url = 'https://invalid-url.com';
    const result = extractIPFSCidFromUrl(url);
    expect(result).toEqual({ cid: null });
  });
});
