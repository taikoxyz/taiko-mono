import { ethers } from 'ethers';

type Network = {
  name: string;
  chainId: number;
  ensAddress?: string;
};

type Networkish = Network | string | number;

export function getInjectedProvider(network: Networkish = 'any') {
  return new ethers.providers.Web3Provider(
    // The globalThis property provides a standard way of accessing the global this value
    // across environments (e.g. unit tests in Node vs browser)
    globalThis.ethereum,
    network,
  );
}

export function getInjectedSigner(
  network: Networkish = 'any',
  addressOrIndex?: string | number,
) {
  return getInjectedProvider(network).getSigner(addressOrIndex);
}
