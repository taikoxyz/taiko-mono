import { PUBLIC_IPFS_GATEWAYS } from '$env/static/public';
import { IpfsError } from '$libs/error';

import { fetchFromIPFSGateways, toIPFSPath } from './ipfsGateways';

// The metadata document of the ERC1155 at 0x1f8483664620ff1278f4c1b0d11e4d7daa11a035
const CID = 'QmUknZyMdhJDgeDGnd3wGB69oC97uGaKLsCgpGg7LKQx1U';
// A v1 CID, the form a subdomain gateway uses
const CID_V1 = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';

describe('toIPFSPath', () => {
  it('returns the cid of an ipfs:// uri', () => {
    expect(toIPFSPath(`ipfs://${CID}`)).toBe(CID);
  });

  it('keeps the sub-path of an ipfs:// uri', () => {
    expect(toIPFSPath(`ipfs://${CID}/42.json`)).toBe(`${CID}/42.json`);
  });

  it('strips the redundant ipfs/ prefix some tokens spell out', () => {
    expect(toIPFSPath(`ipfs://ipfs/${CID}`)).toBe(CID);
  });

  it('returns the cid of a path-style gateway url', () => {
    expect(toIPFSPath(`https://3land.mypinata.cloud/ipfs/${CID}`)).toBe(CID);
  });

  it('keeps everything a path-style gateway url carries after the cid', () => {
    expect(toIPFSPath(`https://ipfs.io/ipfs/${CID}/meta.json?v=2`)).toBe(`${CID}/meta.json?v=2`);
  });

  it('reads a subdomain gateway url, where the cid is the host and not a path segment', () => {
    expect(toIPFSPath(`https://${CID_V1}.ipfs.dweb.link/meta.json`)).toBe(`${CID_V1}/meta.json`);
  });

  it('returns null for a url that names no cid', () => {
    expect(toIPFSPath('https://example.com/metadata/42.json')).toBe(null);
  });

  it('returns null for a cid-shaped path segment that is not served by a gateway', () => {
    // Only /ipfs/<cid> counts. A long base58 run elsewhere in a path is not a claim that the
    // content is addressed by hash, and retrying it against gateways would be nonsense.
    expect(toIPFSPath(`https://example.com/assets/${CID}`)).toBe(null);
    expect(toIPFSPath(`https://example.com/ipfs/not-a-cid`)).toBe(null);
  });

  it('returns null for a data: url, whatever its payload looks like', () => {
    expect(toIPFSPath(`data:image/svg+xml;base64,${CID}${CID}`)).toBe(null);
  });

  it('returns null for a string that is not a url at all', () => {
    expect(toIPFSPath('not a url')).toBe(null);
  });
});

describe('fetchFromIPFSGateways', () => {
  it('runs the real request against a gateway rather than probing one first', async () => {
    const attempt = vi.fn().mockResolvedValue('metadata');

    await expect(fetchFromIPFSGateways(`ipfs://${CID}`, attempt)).resolves.toBe('metadata');
    expect(attempt).toHaveBeenCalledTimes(1);
    expect(attempt.mock.calls[0][0]).toContain(CID);
  });

  it('moves to the next gateway when the request itself fails', async () => {
    // The failure a HEAD probe cannot see: the gateway answers, then rate-limits the body
    const attempt = vi.fn().mockRejectedValueOnce(new Error('429 Too Many Requests')).mockResolvedValueOnce('metadata');

    await expect(fetchFromIPFSGateways(`ipfs://${CID}`, attempt)).resolves.toBe('metadata');
    expect(attempt).toHaveBeenCalledTimes(2);
    expect(attempt.mock.calls[0][0]).not.toBe(attempt.mock.calls[1][0]);
  });

  it('does not spend a round trip re-asking the host that already failed', async () => {
    const attempt = vi.fn().mockResolvedValue('metadata');
    // Built from the same gateway list the resolver uses, so it is the URL it would produce first
    const alreadyFailed = `${PUBLIC_IPFS_GATEWAYS.split(',')[0]}/ipfs/${CID}`;

    await fetchFromIPFSGateways(alreadyFailed, attempt);

    expect(attempt).not.toHaveBeenCalledWith(alreadyFailed);
  });

  it('throws without calling a gateway when the uri names no cid', async () => {
    const attempt = vi.fn();

    await expect(fetchFromIPFSGateways('https://example.com/42.json', attempt)).rejects.toBeInstanceOf(IpfsError);
    expect(attempt).not.toHaveBeenCalled();
  });

  it('throws once every gateway has failed', async () => {
    const attempt = vi.fn().mockRejectedValue(new Error('gateway down'));

    await expect(fetchFromIPFSGateways(`ipfs://${CID}`, attempt)).rejects.toBeInstanceOf(IpfsError);
    expect(attempt).toHaveBeenCalledTimes(PUBLIC_IPFS_GATEWAYS.split(',').length);
  });
});
