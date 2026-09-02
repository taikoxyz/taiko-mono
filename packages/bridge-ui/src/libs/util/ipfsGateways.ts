import { ipfsConfig } from '$config';
import { PUBLIC_IPFS_GATEWAYS } from '$env/static/public';
import { ConfigError, IpfsError } from '$libs/error';

import { getLogger } from './logger';

const gateways = PUBLIC_IPFS_GATEWAYS.split(',') || [];

const log = getLogger('libs:util:ipfsGateways');

// The CID spellings a gateway URL can carry: base58btc v0, and the base32/base58btc/base16
// multibase forms of v1. Anchored, because a CID-shaped run somewhere inside an ordinary path
// says nothing about the URL being content-addressed.
const CID =
  /^(?:Qm[1-9A-HJ-NP-Za-km-z]{44,}|b[A-Za-z2-7]{58,}|B[A-Z2-7]{58,}|z[1-9A-HJ-NP-Za-km-z]{48,}|F[0-9A-F]{50,})$/;

/**
 * The `<cid>[/path]` an IPFS gateway can serve, for an `ipfs://` URI or for an HTTP(S) gateway
 * URL, and null for anything else.
 *
 * An HTTP URL served by a gateway is worth re-pointing at another gateway rather than treating as
 * an opaque address: the content is addressed by hash, so every gateway serves the same bytes,
 * while the single gateway a token happens to name is the part that rots. Tokens routinely point
 * at a project-owned gateway - `https://<project>.mypinata.cloud/ipfs/<cid>` is the common shape -
 * which stops answering once that account lapses even though the content is still pinned and
 * reachable everywhere else.
 *
 * Both gateway spellings are recognised, and only those two: the path form `/ipfs/<cid>[/path]`
 * and the subdomain form `<cid>.ipfs.<host>[/path]`. Matching a CID-shaped segment anywhere in the
 * URL instead would take the host of a subdomain URL for a path, and would claim any ordinary URL
 * that happens to contain a long base58 run.
 */
export function toIPFSPath(uri: string): string | null {
  if (uri.startsWith('ipfs://')) {
    // `ipfs://ipfs/<cid>` is a common enough spelling that the prefix is worth stripping too;
    // gateways serve the CID under `/ipfs/`, so leaving it in produces `/ipfs/ipfs/<cid>`.
    return uri.slice('ipfs://'.length).replace(/^ipfs\//, '');
  }

  let url: URL;
  try {
    url = new URL(uri);
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;

  // Subdomain gateway: <cid>.ipfs.<host>
  const [subdomain, marker] = url.hostname.split('.');
  if (marker === 'ipfs' && CID.test(subdomain)) {
    return `${subdomain}${url.pathname}${url.search}`;
  }

  // Path gateway: /ipfs/<cid>[/path]
  const [, root, cid, ...rest] = url.pathname.split('/');
  if (root !== 'ipfs' || !CID.test(cid ?? '')) return null;

  return [cid, ...rest].join('/') + url.search;
}

/**
 * Runs `attempt` against each configured IPFS gateway in turn and returns the first result it
 * produces, throwing an IpfsError once they are exhausted or the overall time budget is spent.
 *
 * The attempt is the caller's real request - the metadata GET, the image load - rather than a HEAD
 * probe used to pick one gateway that then has to carry it. A gateway that answers HEAD can still
 * fail or rate-limit the request that follows, and with a probe that failure ends the fallback on
 * the very first gateway instead of moving to the next one.
 *
 * @param uri The address to resolve, in any spelling toIPFSPath accepts
 * @param attempt What to do with a candidate gateway URL; rejecting moves on to the next gateway
 * @return result_ Whatever the first successful attempt returned
 */
export async function fetchFromIPFSGateways<T>(uri: string, attempt: (url: string) => Promise<T>): Promise<T> {
  const path = toIPFSPath(uri);
  if (path === null) throw new IpfsError(`Not an IPFS URI: ${uri}`);
  if (gateways.length === 0) throw new ConfigError('No IPFS gateways configured');

  let elapsedTime = 0;
  let lastError: unknown;

  for (const gateway of gateways) {
    const url = `${gateway}/ipfs/${path}`;
    // The caller reached us because `uri` already failed, so asking the same host again is a
    // round trip spent to learn what we know
    if (url === uri) continue;

    const start = Date.now();
    try {
      return await attempt(url);
    } catch (error) {
      lastError = error;
      log('IPFS gateway failed', url, error);
      elapsedTime += Date.now() - start;
      if (elapsedTime > ipfsConfig.overallTimeout) break;
    }
  }

  throw new IpfsError('Failed to retrieve from IPFS gateways', { cause: lastError });
}
