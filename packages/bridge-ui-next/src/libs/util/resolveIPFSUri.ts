import axios, { type AxiosRequestConfig } from "axios";

import { ipfsConfig } from "$config";
import { ConfigError, IpfsError } from "$libs/error";
import { publicEnv } from "@/config/env";

// SvelteKit `$env/static/public` PUBLIC_IPFS_GATEWAYS -> NEXT_PUBLIC_IPFS_GATEWAYS (via publicEnv).
const gateways = publicEnv.IPFS_GATEWAYS.split(",") || [];

const axiosConfig: AxiosRequestConfig = {
  timeout: ipfsConfig.gatewayTimeout,
};

export async function resolveIPFSUri(uri: string): Promise<string> {
  const cid = uri.replace("ipfs://", "");
  let elapsedTime = 0;
  if (gateways.length === 0)
    throw new ConfigError("No IPFS gateways configured");
  for (const gateway of gateways) {
    const start = Date.now();
    try {
      const url = `${gateway}/ipfs/${cid}`;
      await axios.head(url, axiosConfig);
      return url; // Return the first successful gateway URL
    } catch {
      elapsedTime += Date.now() - start;
      if (elapsedTime > ipfsConfig.overallTimeout) {
        break;
      }
    }
  }
  throw new IpfsError("Failed to retrieve metadata from IPFS gateways");
}
