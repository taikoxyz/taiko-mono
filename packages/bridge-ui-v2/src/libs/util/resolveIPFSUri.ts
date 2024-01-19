import axios, { type AxiosRequestConfig } from 'axios';

const REQUEST_TIMEOUT_IN_MS = 200;
const MAX_RETRY_DURATION_IN_MS = 1000;
const GATEWAYS = ['https://ipfs.io/ipfs/', 'https://gateway.pinata.cloud/ipfs/'];

const axiosConfig: AxiosRequestConfig = {
  timeout: REQUEST_TIMEOUT_IN_MS,
};

export async function resolveIPFSUri(uri: string): Promise<string> {
  const cid = uri.replace('ipfs://', '');
  let elapsedTime = 0;
  for (const gateway of GATEWAYS) {
    const start = Date.now();
    try {
      const url = `${gateway}${cid}`;
      await axios.head(url, axiosConfig);
      return url; // Return the first successful gateway URL
    } catch (error) {
      elapsedTime += Date.now() - start;
      if (elapsedTime > MAX_RETRY_DURATION_IN_MS) {
        break;
      }
    }
  }
  throw new Error('Failed to retrieve metadata from IPFS gateways');
}
