import axios, { type AxiosRequestConfig } from 'axios';

import { ipfsConfig } from '$config';
import { PUBLIC_IPFS_GATEWAYS } from '$env/static/public';
import { ConfigError, IpfsError } from '$libs/error';

const gateways = PUBLIC_IPFS_GATEWAYS.split(',') || [];

const axiosConfig: AxiosRequestConfig = {
  timeout: ipfsConfig.gatewayTimeout,
};

export async function resolveIPFSUri(uri: string): Promise<string> {
  const cid = uri.replace('ipfs://', '');
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
