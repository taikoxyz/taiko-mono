import axios from 'axios';

import { IpfsError } from '$libs/error';

import { resolveIPFSUri, toIPFSPath } from './resolveIPFSUri';

vi.mock('axios');

// The metadata document of the ERC1155 at 0x1f8483664620ff1278f4c1b0d11e4d7daa11a035
const CID = 'QmUknZyMdhJDgeDGnd3wGB69oC97uGaKLsCgpGg7LKQx1U';

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

  it('returns the cid of an http gateway url', () => {
    expect(toIPFSPath(`https://3land.mypinata.cloud/ipfs/${CID}`)).toBe(CID);
  });

  it('keeps everything the gateway url carries after the cid', () => {
    expect(toIPFSPath(`https://ipfs.io/ipfs/${CID}/meta.json?v=2`)).toBe(`${CID}/meta.json?v=2`);
  });

  it('returns null for a url that names no cid', () => {
    expect(toIPFSPath('https://example.com/metadata/42.json')).toBe(null);
  });
});

describe('resolveIPFSUri', () => {
  beforeEach(() => {
    vi.mocked(axios.head).mockReset();
  });

  it('re-points a gateway url at a configured gateway', async () => {
    vi.mocked(axios.head).mockResolvedValue({ status: 200 });

    // The token's own gateway is the part that rots; the CID is not, so the content stays
    // reachable through any other gateway.
    const url = await resolveIPFSUri(`https://3land.mypinata.cloud/ipfs/${CID}`);

    expect(url).toContain(CID);
    expect(url).not.toContain('mypinata');
  });

  it('still resolves an ipfs:// uri', async () => {
    vi.mocked(axios.head).mockResolvedValue({ status: 200 });

    expect(await resolveIPFSUri(`ipfs://${CID}`)).toContain(CID);
  });

  it('throws without calling a gateway when the uri names no cid', async () => {
    await expect(resolveIPFSUri('https://example.com/metadata/42.json')).rejects.toBeInstanceOf(IpfsError);
    expect(axios.head).not.toHaveBeenCalled();
  });

  it('throws when every gateway fails', async () => {
    vi.mocked(axios.head).mockRejectedValue(new Error('gateway down'));

    await expect(resolveIPFSUri(`ipfs://${CID}`)).rejects.toBeInstanceOf(IpfsError);
  });
});
