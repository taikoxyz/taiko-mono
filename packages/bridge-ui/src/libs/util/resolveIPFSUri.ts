import axios, { type AxiosRequestConfig } from 'axios';

import { ipfsConfig } from '$config';
import { PUBLIC_IPFS_GATEWAYS } from '$env/static/public';
import { ConfigError, IpfsError } from '$libs/error';

import { extractIPFSCidFromUrl } from './extractIPFSCidFromUrl';

const gateways = PUBLIC_IPFS_GATEWAYS.split(',') || [];

const axiosConfig: AxiosRequestConfig = {
  timeout: ipfsConfig.gatewayTimeout,
};

/**
 * The `<cid>[/path]` an IPFS gateway can serve, for an `ipfs://` URI or for an HTTP(S) URL that
 * already names a CID, and null for anything else.
 *
 * An HTTP URL that names a CID is worth re-pointing at another gateway rather than treating as
 * an opaque address: the content is addressed by hash, so every gateway serves the same bytes,
 * while the single gateway a token happens to name is the part that rots. Tokens routinely
 * point at a project-owned gateway - `https://<project>.mypinata.cloud/ipfs/<cid>` is the
 * common shape - which stops answering once that account lapses even though the content is
 * still pinned and reachable everywhere else.
 */
export function toIPFSPath(uri: string): string | null {
  if (uri.startsWith('ipfs://')) {
    // `ipfs://ipfs/<cid>` is a common enough spelling that the prefix is worth stripping too;
    // gateways serve the CID under `/ipfs/`, so leaving it in produces `/ipfs/ipfs/<cid>`.
    return uri.slice('ipfs://'.length).replace(/^ipfs\//, '');
  }

  const { cid } = extractIPFSCidFromUrl(uri);
  if (!cid) return null;

  // Everything from the CID onwards: the sub-path and query a gateway URL may carry after it
  // are part of the address, not of the host that happened to serve it.
  return uri.slice(uri.indexOf(cid));
}

export async function resolveIPFSUri(uri: string): Promise<string> {
  const cid = toIPFSPath(uri);
  if (cid === null) throw new IpfsError(`Not an IPFS URI: ${uri}`);
  let elapsedTime = 0;
  if (gateways.length === 0) throw new ConfigError('No IPFS gateways configured');
  for (const gateway of gateways) {
    const start = Date.now();
    try {
      const url = `${gateway}/ipfs/${cid}`;
      await axios.head(url, axiosConfig);
      return url; // Return the first successful gateway URL
    } catch (error) {
      elapsedTime += Date.now() - start;
      if (elapsedTime > ipfsConfig.overallTimeout) {
        break;
      }
    }
  }
  throw new IpfsError('Failed to retrieve metadata from IPFS gateways');
}
