import axios from 'axios';
import type { ethers } from 'ethers';
import type { APIResponse, APIResponseEvent } from 'src/domain/api';

export const getBlockProvenEvents = async (
  eventIndexerApiUrl: string,
  signer: ethers.Signer,
): Promise<APIResponseEvent[]> => {
  const resp = await axios.get<APIResponse>(`${eventIndexerApiUrl}/events`, {
    params: {
      event: 'BlockProven',
      address: await signer.getAddress(),
    },
  });

  return resp.data.items;
};
