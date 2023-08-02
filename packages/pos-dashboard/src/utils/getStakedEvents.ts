import axios from 'axios';
import type { ethers } from 'ethers';
import type { APIResponse, APIResponseEvent } from '../domain/api';

export const getStakedEvents = async (
  eventIndexerApiUrl: string,
  signer: ethers.Signer,
): Promise<APIResponseEvent[]> => {
  const resp = await axios.get<APIResponse>(`${eventIndexerApiUrl}/events`, {
    params: {
      event: 'Staked',
      address: await signer.getAddress(),
    },
  });

  return resp.data.items;
};
