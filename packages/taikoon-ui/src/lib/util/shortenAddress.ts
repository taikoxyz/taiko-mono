import type { IAddress } from '../../types';
import { web3modal } from '../connect';
import { getName } from '../ens';

export async function shortenAddress(address: IAddress, charsStart = 5, charsEnd = 3, sep = '…'): Promise<string> {
  if (!address) return '0x';
  const shortened = [address.slice(0, charsStart), address.slice(-charsEnd)].join(sep);

  try {
    const { selectedNetworkId } = web3modal.getState();
    if (!selectedNetworkId) {
      return shortened;
    }

    const name = await getName(address);
    if (name) {
      return name;
    }
  } catch (e) {
    // console.warn(e);
  }

  return shortened;
}
